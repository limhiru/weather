package com.limhiru.weather

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.limhiru.weather/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    try {
                        WeatherWidgetProvider.update(this, JSONObject(call.arguments as Map<*, *>))
                        result.success(null)
                    } catch (error: Exception) { result.error("widget_update", "위젯을 갱신하지 못했어요.", null) }
                } else result.notImplemented()
            }
    }
}

class WeatherWidgetProvider : android.appwidget.AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val cached = context.getSharedPreferences("weather_widget", Context.MODE_PRIVATE).getString("payload", null)
        val data = try { if (cached == null) null else JSONObject(cached) } catch (_: Exception) { null }
        ids.forEach { render(context, manager, it, data) }
    }
    companion object {
        fun update(context: Context, data: JSONObject) {
            context.getSharedPreferences("weather_widget", Context.MODE_PRIVATE).edit().putString("payload", data.toString()).apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, WeatherWidgetProvider::class.java))
            ids.forEach { render(context, manager, it, data) }
        }
        private fun render(context: Context, manager: AppWidgetManager, id: Int, data: JSONObject?) {
            val views = RemoteViews(context.packageName, R.layout.weather_widget)
            if (data == null || data.optBoolean("isDemo", false)) {
                views.setTextViewText(R.id.widget_city, "물결 날씨")
                views.setTextViewText(R.id.widget_temp, "--°")
                views.setTextViewText(R.id.widget_condition, "앱을 열어 날씨를 불러오세요")
                views.setTextViewText(R.id.widget_updated, "Power by 기상청")
            } else {
                val current = data.optJSONObject("current")
                val city = data.optString("city", "서울")
                views.setTextViewText(R.id.widget_city, city)
                val temp = current?.optDouble("temperature", Double.NaN)
                views.setTextViewText(R.id.widget_temp, if (temp == null || temp.isNaN()) "--°" else "${temp.toInt()}°")
                val sky = current?.optString("condition", "clear") ?: "clear"
                val label = when (sky) { "rain" -> "비"; "snow" -> "눈"; "sleet" -> "비와 눈"; "cloudy" -> "구름 많음"; "overcast" -> "흐림"; else -> "맑음" }
                views.setTextViewText(R.id.widget_condition, label)
                val humidity = current?.optDouble("humidity", Double.NaN)
                val humText = if (humidity == null || humidity.isNaN()) "" else "  ·  습도 ${humidity.toInt()}%"
                views.setTextViewText(R.id.widget_updated, "$humText  Power by 기상청")
            }
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) views.setOnClickPendingIntent(R.id.widget_root, android.app.PendingIntent.getActivity(context, 0, launch, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE))
            manager.updateAppWidget(id, views)
        }
    }
}
