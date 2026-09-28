package app.thetwodigiter.devsprint

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class TodayWidgetProvider : AppWidgetProvider() {
    companion object {
        fun updateAll(context: Context) {
            val m=AppWidgetManager.getInstance(context); val c=android.content.ComponentName(context, TodayWidgetProvider::class.java)
            m.getAppWidgetIds(c).forEach { update(context,m,it) }
        }
        private fun update(context: Context,m:AppWidgetManager,id:Int){
            val s=WidgetState.load(context); val v=RemoteViews(context.packageName,R.layout.widget_today)
            v.setTextViewText(R.id.today_completed,s.optInt("todayCompleted",0).toString())
            v.setTextViewText(R.id.today_minutes,WidgetState.formatMinutes(s.optInt("todayMinutes",0)))
            v.setTextViewText(R.id.today_streak,"${s.optInt("currentStreak",0)}d")
            WidgetState.setClick(v,context,R.id.today_root,1101); m.updateAppWidget(id,v)
        }
    }
    override fun onUpdate(c:Context,m:AppWidgetManager,ids:IntArray){ids.forEach{update(c,m,it)}}
    override fun onAppWidgetOptionsChanged(c:Context,m:AppWidgetManager,id:Int,b:android.os.Bundle){super.onAppWidgetOptionsChanged(c,m,id,b);update(c,m,id)}
    override fun onReceive(c:Context,i:Intent){super.onReceive(c,i);if(i.action==WidgetState.ACTION_UPDATE)updateAll(c)}
}
