package com.limhiru.weather

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.PI
import kotlin.math.acos
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.limhiru.weather/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    try {
                        WeatherWidgetProvider.update(this, JSONObject(call.arguments as Map<*, *>))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("widget_update", "위젯을 갱신하지 못했어요.", null)
                    }
                } else result.notImplemented()
            }
    }
}

class WeatherWidgetProvider : android.appwidget.AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val cached = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(PAYLOAD, null)
        val data = try { if (cached == null) null else JSONObject(cached) } catch (_: Exception) { null }
        ids.forEach { render(context, manager, it, data) }
    }

    companion object {
        const val PREFERENCES = "weather_widget"
        const val PAYLOAD = "payload"

        fun update(context: Context, data: JSONObject) {
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .edit().putString(PAYLOAD, data.toString()).apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, WeatherWidgetProvider::class.java))
            ids.forEach { render(context, manager, it, data) }
        }

        private fun render(context: Context, manager: AppWidgetManager, id: Int, data: JSONObject?) {
            val views = RemoteViews(context.packageName, R.layout.weather_widget)
            val current = data?.optJSONObject("current")
            val hasWeather = data != null && !data.optBoolean("isDemo", false) && current != null
            val city = data?.optString("city", "서울") ?: "물결 날씨"
            val sky = current?.optString("condition", "clear") ?: "clear"
            views.setTextViewText(R.id.widget_city, city)
            views.setTextViewText(R.id.widget_temp, temperature(current?.optDouble("temperature", Double.NaN)))
            views.setTextViewText(R.id.widget_condition, if (hasWeather) conditionLabel(sky) else "앱을 열어 날씨를 불러오세요")
            val humidity = current?.optDouble("humidity", Double.NaN)
            val humidityLabel = if (humidity != null && humidity.isFinite()) "습도 ${humidity.roundToInt()}%" else "기상청 예보"
            views.setTextViewText(R.id.widget_updated, if (hasWeather) "기상청 제공 · $humidityLabel" else "기상청 제공")

            val latitude = data?.optDouble("latitude", Double.NaN) ?: Double.NaN
            val longitude = data?.optDouble("longitude", Double.NaN) ?: Double.NaN
            val (sunrise, sunset) = if (latitude.isFinite() && longitude.isFinite()) {
                solarTimes(latitude, longitude)
            } else "--:--" to "--:--"
            views.setTextViewText(R.id.widget_sunrise, "일출  $sunrise")
            views.setTextViewText(R.id.widget_sunset, "일몰  $sunset")

            val hours = data?.optJSONArray("hourly")
            val kstNow = Calendar.getInstance(TimeZone.getTimeZone("Asia/Seoul"), Locale.KOREA).apply {
                set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }.time
            val hourRows = (0 until (hours?.length() ?: 0)).mapNotNull { hours?.optJSONObject(it) }
                .filter { row -> parseForecastDate(row.optString("time", ""))?.time?.let { it >= kstNow.time } ?: true }
                .take(4)
            val timeIds = intArrayOf(R.id.widget_hour_time_0, R.id.widget_hour_time_1, R.id.widget_hour_time_2, R.id.widget_hour_time_3)
            val iconIds = intArrayOf(R.id.widget_hour_icon_0, R.id.widget_hour_icon_1, R.id.widget_hour_icon_2, R.id.widget_hour_icon_3)
            val tempIds = intArrayOf(R.id.widget_hour_temp_0, R.id.widget_hour_temp_1, R.id.widget_hour_temp_2, R.id.widget_hour_temp_3)
            val popIds = intArrayOf(R.id.widget_hour_pop_0, R.id.widget_hour_pop_1, R.id.widget_hour_pop_2, R.id.widget_hour_pop_3)
            for (index in timeIds.indices) {
                val hour = hourRows.getOrNull(index)
                if (hour == null) {
                    views.setTextViewText(timeIds[index], "—")
                    views.setImageViewResource(iconIds[index], R.drawable.widget_sun)
                    views.setTextViewText(tempIds[index], "—°")
                    views.setTextViewText(popIds[index], "")
                } else {
                    val condition = hour.optString("condition", "clear")
                    views.setTextViewText(timeIds[index], forecastHour(hour.optString("time", "")))
                    views.setImageViewResource(iconIds[index], conditionIcon(condition))
                    views.setTextViewText(tempIds[index], temperature(hour.optDouble("temperature", Double.NaN)))
                    val pop = hour.optDouble("precipitationProbability", Double.NaN)
                    views.setTextViewText(popIds[index], if (pop.isFinite()) "강수 ${pop.roundToInt()}%" else conditionLabel(condition))
                }
            }

            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    android.app.PendingIntent.getActivity(
                        context, 0, launch,
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }
            val serviceIntent = Intent(context, WeatherWidgetService::class.java)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            views.setRemoteAdapter(R.id.widget_weather_flipper, serviceIntent)
            views.setEmptyView(R.id.widget_weather_flipper, R.id.widget_weather_empty)
            manager.updateAppWidget(id, views)
            manager.notifyAppWidgetViewDataChanged(id, R.id.widget_weather_flipper)
        }

        private fun temperature(value: Double?): String =
            if (value == null || !value.isFinite()) "—°" else "${value.roundToInt()}°"

        private fun forecastHour(value: String): String = try {
            val date = parseForecastDate(value) ?: return "—"
            val formatter = SimpleDateFormat("H'시'", Locale.KOREAN)
            formatter.timeZone = TimeZone.getTimeZone("Asia/Seoul")
            formatter.format(date)
        } catch (_: Exception) { "—" }

        private fun parseForecastDate(value: String): Date? = try {
            val parser = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US)
            parser.timeZone = TimeZone.getTimeZone("UTC")
            parser.parse(value)
        } catch (_: Exception) { null }

        fun conditionLabel(condition: String): String = when (condition) {
            "rain" -> "비"
            "snow" -> "눈"
            "sleet" -> "비와 눈"
            "cloudy" -> "구름 많음"
            "overcast" -> "흐림"
            else -> "맑음"
        }

        fun conditionIcon(condition: String): Int = when (condition) {
            "rain" -> R.drawable.widget_rain
            "snow" -> R.drawable.widget_snow
            "sleet" -> R.drawable.widget_sleet
            "cloudy" -> R.drawable.widget_cloudy
            "overcast" -> R.drawable.widget_cloud
            else -> R.drawable.widget_sun
        }

        private fun solarTimes(latitude: Double, longitude: Double): Pair<String, String> {
            val kst = Calendar.getInstance(TimeZone.getTimeZone("Asia/Seoul"), Locale.KOREA)
            val day = kst.get(Calendar.DAY_OF_YEAR).toDouble()
            val daysInYear = if (kst.getActualMaximum(Calendar.DAY_OF_YEAR) == 366) 366.0 else 365.0
            val gamma = 2.0 * PI / daysInYear * (day - 1.0)
            val equation = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma) - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
            val declination = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma) - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
            val latitudeRadians = Math.toRadians(latitude)
            val zenith = Math.toRadians(90.833)
            val cosine = (cos(zenith) - sin(latitudeRadians) * sin(declination)) / (cos(latitudeRadians) * cos(declination))
            if (cosine !in -1.0..1.0) return "--:--" to "--:--"
            val angle = Math.toDegrees(acos(cosine))
            val noonUtc = 720.0 - 4.0 * longitude - equation
            fun localTime(utcMinutes: Double): String {
                val minutes = ((utcMinutes + 540.0).roundToInt() % 1440 + 1440) % 1440
                return String.format(Locale.KOREA, "%02d:%02d", minutes / 60, minutes % 60)
            }
            return localTime(noonUtc - 4.0 * angle) to localTime(noonUtc + 4.0 * angle)
        }
    }
}

class WeatherWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsService.RemoteViewsFactory = WeatherWidgetFactory(applicationContext)
}

private class WeatherWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    override fun onCreate() = Unit
    override fun onDataSetChanged() = Unit
    override fun onDestroy() = Unit
    override fun getCount(): Int = 2
    override fun getViewAt(position: Int): RemoteViews {
        val payload = context.getSharedPreferences(WeatherWidgetProvider.PREFERENCES, Context.MODE_PRIVATE)
            .getString(WeatherWidgetProvider.PAYLOAD, null)
        val condition = try {
            JSONObject(payload ?: "{}").optJSONObject("current")?.optString("condition", "clear") ?: "clear"
        } catch (_: Exception) { "clear" }
        val view = RemoteViews(context.packageName, R.layout.weather_widget_frame)
        view.setImageViewResource(R.id.widget_weather_frame_icon, WeatherWidgetProvider.conditionIcon(condition))
        view.setContentDescription(R.id.widget_weather_frame_icon, WeatherWidgetProvider.conditionLabel(condition))
        view.setFloat(R.id.widget_weather_frame_icon, "setTranslationY", if (position == 0) -2.5f else 2.5f)
        view.setInt(R.id.widget_weather_frame_icon, "setImageAlpha", if (position == 0) 230 else 255)
        return view
    }
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
