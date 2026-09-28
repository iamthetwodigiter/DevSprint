package app.thetwodigiter.devsprint

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class MomentumWidgetProvider : AppWidgetProvider() {
    companion object {
        fun updateAll(c:Context){val m=AppWidgetManager.getInstance(c);val n=android.content.ComponentName(c,MomentumWidgetProvider::class.java);m.getAppWidgetIds(n).forEach{update(c,m,it)}}
        private fun update(c:Context,m:AppWidgetManager,id:Int){val s=WidgetState.load(c);val v=RemoteViews(c.packageName,R.layout.widget_momentum);v.setTextViewText(R.id.momentum_streak,"${s.optInt("currentStreak",0)} days");v.setTextViewText(R.id.momentum_week,"${s.optInt("weekCompleted",0)} completed");v.setTextViewText(R.id.momentum_time,WidgetState.formatMinutes(s.optInt("weekMinutes",0)));WidgetState.setClick(v,c,R.id.momentum_root,1102);m.updateAppWidget(id,v)}
    }
    override fun onUpdate(c:Context,m:AppWidgetManager,ids:IntArray){ids.forEach{update(c,m,it)}}
    override fun onAppWidgetOptionsChanged(c:Context,m:AppWidgetManager,id:Int,b:android.os.Bundle){super.onAppWidgetOptionsChanged(c,m,id,b);update(c,m,id)}
    override fun onReceive(c:Context,i:Intent){super.onReceive(c,i);if(i.action==WidgetState.ACTION_UPDATE)updateAll(c)}
}
