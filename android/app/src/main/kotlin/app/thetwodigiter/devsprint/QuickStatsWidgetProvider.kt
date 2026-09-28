package app.thetwodigiter.devsprint

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class QuickStatsWidgetProvider : AppWidgetProvider() {
    companion object {
        fun updateAll(c:Context){val m=AppWidgetManager.getInstance(c);val n=android.content.ComponentName(c,QuickStatsWidgetProvider::class.java);m.getAppWidgetIds(n).forEach{update(c,m,it)}}
        private fun update(c:Context,m:AppWidgetManager,id:Int){val s=WidgetState.load(c);val v=RemoteViews(c.packageName,R.layout.widget_quick_stats);v.setTextViewText(R.id.quick_completed,s.optInt("completed",0).toString());v.setTextViewText(R.id.quick_failed,s.optInt("failed",0).toString());v.setTextViewText(R.id.quick_score,if(s.optInt("averageScore",0)>0)s.optInt("averageScore").toString()+"/100" else "—");v.setTextViewText(R.id.quick_time,WidgetState.formatMinutes(s.optInt("focusedMinutes",0)));WidgetState.setClick(v,c,R.id.quick_root,1106);m.updateAppWidget(id,v)}
    }
    override fun onUpdate(c:Context,m:AppWidgetManager,ids:IntArray){ids.forEach{update(c,m,it)}}
    override fun onAppWidgetOptionsChanged(c:Context,m:AppWidgetManager,id:Int,b:android.os.Bundle){super.onAppWidgetOptionsChanged(c,m,id,b);update(c,m,id)}
    override fun onReceive(c:Context,i:Intent){super.onReceive(c,i);if(i.action==WidgetState.ACTION_UPDATE)updateAll(c)}
}
