import json
import os
import threading
import unittest
from datetime import datetime
from http.server import ThreadingHTTPServer
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import urlopen
from server.weather import KST, WeatherError, WeatherService, condition, grid, issue_times, normalize, number, fetch
from server.app import Handler

class WeatherTests(unittest.TestCase):
    def test_seoul_grid(self):
        self.assertEqual(grid(37.5665,126.978), (60,127))
        self.assertEqual(grid(35.1796,129.0756), (98,76))
    def test_invalid_coordinates(self):
        for lat,lon in [(0,0),(float('nan'),127),(37,float('inf'))]:
            with self.assertRaises(WeatherError): grid(lat,lon)
    def test_issue_rollover_and_publication_delay(self):
        obs,forecast=issue_times(datetime(2026,1,1,0,9,tzinfo=KST))
        self.assertEqual(obs.strftime('%Y%m%d%H%M'),'202512312300')
        self.assertEqual(forecast.strftime('%Y%m%d%H%M'),'202512312300')
        for minute,expected in [(9,23),(10,2)]:
            self.assertEqual(issue_times(datetime(2026,1,1,2,minute,tzinfo=KST))[1].hour,expected)
        self.assertEqual(issue_times(datetime(2026,1,1,8,40,tzinfo=KST))[0].hour,8)
    def test_conditions(self):
        for code,expected in [(1,'rain'),(2,'sleet'),(3,'snow'),(4,'rain'),(5,'rain'),(6,'sleet'),(7,'snow')]:
            self.assertEqual(condition(1,code),expected)
        self.assertEqual(condition(4,0),'overcast')
    def test_missing_values_are_not_zero(self):
        self.assertIsNone(number('-999'))
        self.assertIsNone(number('NaN'))
        self.assertIsNone(number(None))
        self.assertEqual(number('0'),0)
    def test_normalization_kst_and_partial_range(self):
        now=datetime(2026,10,5,23,30,tzinfo=KST)
        observations=[{'category':'T1H','obsrValue':'20'},{'category':'PTY','obsrValue':'0'}]
        forecasts=[]
        for date,hour,temp in [('20261005','2200','25'),('20261005','2300','20'),('20261006','0000','18')]:
            for category,value in [('TMP',temp),('SKY','1'),('PTY','0'),('POP','10')]:
                forecasts.append(dict(fcstDate=date,fcstTime=hour,category=category,fcstValue=value))
        result=normalize(observations,forecasts,now,now,now)
        self.assertEqual(len(result['hourly']),2)
        self.assertEqual(result['daily'][0]['high'],20)
        self.assertEqual(result['daily'][1]['date'],'2026-10-06')
        self.assertIsNone(result['current']['humidity'])
        self.assertFalse(result['isDemo'])
    def test_missing_key(self):
        with patch.dict(os.environ,{'KMA_SERVICE_KEY':''}):
            with self.assertRaises(WeatherError) as error: WeatherService().get(37.5665,126.978)
            self.assertEqual(error.exception.status,503)
    def test_upstream_failure_does_not_leak_key(self):
        with patch('server.weather.urlopen',side_effect=Exception('secret-key')):
            with self.assertRaises(WeatherError) as error: fetch('getUltraSrtNcst',datetime.now(KST),60,127,'secret-key')
            self.assertNotIn('secret-key',str(error.exception))
    def test_cache_shares_grid_requests(self):
        result={'isDemo':False}
        with patch.dict(os.environ,{'KMA_SERVICE_KEY':'test'}), patch('server.weather.fetch',return_value=[]) as upstream, patch('server.weather.normalize',return_value=result):
            service=WeatherService()
            self.assertEqual(service.get(37.5665,126.978),result)
            service.get(37.5665,126.978)
            self.assertEqual(upstream.call_count,2)

class HTTPTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True)
        cls.thread.start()
        cls.base=f'http://127.0.0.1:{cls.server.server_port}'
    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()
    def test_health(self):
        with urlopen(self.base+'/health') as response:
            self.assertEqual(json.load(response)['status'],'ok')
    def test_validation_and_key_errors(self):
        with patch.dict(os.environ,{'KMA_SERVICE_KEY':''}):
            for path,status in [('/v1/weather',400),('/v1/weather?lat=nan&lon=127',400),('/v1/weather?lat=37.56&lon=126.97',503),('/missing',404)]:
                with self.assertRaises(HTTPError) as error: urlopen(self.base+path)
                self.assertEqual(error.exception.code,status)
                self.assertIn('error',json.load(error.exception))
                error.exception.close()

if __name__ == '__main__': unittest.main()
