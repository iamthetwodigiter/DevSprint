package app.thetwodigiter.devsprint

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class SkillWidgetProvider : AppWidgetProvider() {
    companion object {
        fun updateAll(c:Context){val m=AppWidgetManager.getInstance(c);val n=android.content.ComponentName(c,SkillWidgetProvider::class.java);m.getAppWidgetIds(n).forEach{update(c,m,it)}}
        private fun update(c:Context,m:AppWidgetManager,id:Int){val s=WidgetState.load(c);val v=RemoteViews(c.packageName,R.layout.widget_skill);val o=s.optJSONObject("skills");val keys=mutableListOf<String>();if(o!=null){val it=o.keys();while(it.hasNext())keys.add(it.next())};keys.sortByDescending{o?.optInt(it,0)?:0};val top=keys.take(5);val ids=intArrayOf(R.id.skill_1,R.id.skill_2,R.id.skill_3,R.id.skill_4,R.id.skill_5);for(i in ids.indices){if(i<top.size){val k=top[i];v.setTextViewText(ids[i],"$k  ${o?.optInt(k,0)?:0}")}else v.setTextViewText(ids[i],"")};WidgetState.setClick(v,c,R.id.skill_root,1105);m.updateAppWidget(id,v)}
    }
    override fun onUpdate(c:Context,m:AppWidgetManager,ids:IntArray){ids.forEach{update(c,m,it)}}
    override fun onAppWidgetOptionsChanged(c:Context,m:AppWidgetManager,id:Int,b:android.os.Bundle){super.onAppWidgetOptionsChanged(c,m,id,b);update(c,m,id)}
    override fun onReceive(c:Context,i:Intent){super.onReceive(c,i);if(i.action==WidgetState.ACTION_UPDATE)updateAll(c)}
}
