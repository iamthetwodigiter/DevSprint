package app.thetwodigiter.devsprint

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class NextSprintWidgetProvider : AppWidgetProvider() {
    companion object {
        fun updateAll(c:Context){val m=AppWidgetManager.getInstance(c);val n=android.content.ComponentName(c,NextSprintWidgetProvider::class.java);m.getAppWidgetIds(n).forEach{update(c,m,it)}}
        private fun update(c:Context,m:AppWidgetManager,id:Int){val s=WidgetState.load(c);val v=RemoteViews(c.packageName,R.layout.widget_next_sprint);v.setTextViewText(R.id.next_title,s.optString("nextSprintTitle","No active sprint"));v.setTextViewText(R.id.next_meta,listOf(s.optString("nextSprintLanguage",""),s.optString("nextSprintPractice","")).filter{it.isNotBlank()}.joinToString(" • "));val d=s.optString("nextSprintDeadline","");v.setTextViewText(R.id.next_deadline,if(d.isBlank()) "Ready when you are" else "$d min");WidgetState.setClick(v,c,R.id.next_root,1104);m.updateAppWidget(id,v)}
    }
    override fun onUpdate(c:Context,m:AppWidgetManager,ids:IntArray){ids.forEach{update(c,m,it)}}
    override fun onAppWidgetOptionsChanged(c:Context,m:AppWidgetManager,id:Int,b:android.os.Bundle){super.onAppWidgetOptionsChanged(c,m,id,b);update(c,m,id)}
    override fun onReceive(c:Context,i:Intent){super.onReceive(c,i);if(i.action==WidgetState.ACTION_UPDATE)updateAll(c)}
}
