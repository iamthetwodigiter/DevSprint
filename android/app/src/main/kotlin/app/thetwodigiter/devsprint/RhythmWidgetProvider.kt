package app.thetwodigiter.devsprint

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class RhythmWidgetProvider : AppWidgetProvider() {
    companion object {
        fun updateAll(c:Context){val m=AppWidgetManager.getInstance(c);val n=android.content.ComponentName(c,RhythmWidgetProvider::class.java);m.getAppWidgetIds(n).forEach{update(c,m,it)}}
        private fun update(c:Context,m:AppWidgetManager,id:Int){val s=WidgetState.load(c);val v=RemoteViews(c.packageName,R.layout.widget_rhythm);v.setTextViewText(R.id.rhythm_streak,"${s.optInt("currentStreak",0)}d");v.setTextViewText(R.id.rhythm_week,"${s.optInt("weekCompleted",0)} / 7");WidgetState.setClick(v,c,R.id.rhythm_root,1103);m.updateAppWidget(id,v)}
    }
    override fun onUpdate(c:Context,m:AppWidgetManager,ids:IntArray){ids.forEach{update(c,m,it)}}
    override fun onAppWidgetOptionsChanged(c:Context,m:AppWidgetManager,id:Int,b:android.os.Bundle){super.onAppWidgetOptionsChanged(c,m,id,b);update(c,m,id)}
    override fun onReceive(c:Context,i:Intent){super.onReceive(c,i);if(i.action==WidgetState.ACTION_UPDATE)updateAll(c)}
}
