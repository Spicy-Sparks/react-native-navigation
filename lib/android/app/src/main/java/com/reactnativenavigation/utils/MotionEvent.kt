package com.reactnativenavigation.utils

import android.graphics.Rect
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import com.reactnativenavigation.BuildConfig

val hitRect = Rect()

fun MotionEvent.coordinatesInsideView(view: View?): Boolean {
    var hit = false

    var viewGroup = (view as? ViewGroup)?.getChildAt(0) as? ViewGroup
    if (viewGroup != null && viewGroup.childCount > 0) {
        val content = viewGroup.getChildAt(0)
        content.getHitRect(hitRect)
        hit = hitRect.contains(x.toInt(), y.toInt())
    }
    else {
        viewGroup = (view as? ViewGroup)
        if (viewGroup != null && viewGroup.childCount > 0) {
            val content = viewGroup.getChildAt(0)
            content.getHitRect(hitRect)
            hit = hitRect.contains(x.toInt(), y.toInt())
        }
        else if (view != null) {
            view.getHitRect(hitRect)
            hit = hitRect.contains(x.toInt(), y.toInt())
        }
    }

    return hit
}