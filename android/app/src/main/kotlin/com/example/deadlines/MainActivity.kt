package com.example.deadlines

import android.app.Notification
import android.app.NotificationManager
import android.content.Context.NOTIFICATION_SERVICE
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity()
//{
//    private val CHANNEL = "deadlines/alarm_prio_hack";
//    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//        super.configureFlutterEngine(flutterEngine)
//
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
//            call, result ->
//            Log.i("x", "call m: "+call.method)
//            Log.i("x", "call args: "+call.arguments)
//            Log.i("x", "call id: "+call.argument("id"))
//            try {
//                val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
//                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
//                    Log.i("x", "test 1")
//                    Log.i("x", "notificationManager.activeNotifications: "+notificationManager.activeNotifications.toList().toString())
//                    val active = notificationManager.activeNotifications.first { n -> n.id.toString() == call.argument("id") }
//                    active.notification.priority = Notification.PRIORITY_HIGH
//                    Log.i("x", "test 2")
//                    notificationManager.notify(active.id, active.notification)
//                    result.success(call.method + " - yes")
//                } else {
//                    result.error("tiny version", "tiny version", "tiny version")
//                }
//            } catch (e: Exception) {
//                result.error(e.message!!, e.message, call.arguments.toString())
//            }
//        }
//    }
//}

