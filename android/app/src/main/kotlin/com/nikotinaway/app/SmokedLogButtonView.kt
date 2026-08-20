package com.nikotinaway.app

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.view.MotionEvent
import android.view.View

/// The floating quick-log button.
///
/// Uses a short hold rather than a tap: this thing sits on top of whatever
/// the user is doing all day, and a stray brush against it should not write
/// "I smoked" into their history. Background stays fully transparent — only
/// the butterfly/chain mark itself is drawn, so it reads as a mark floating
/// on the screen rather than a disc sitting on top of other apps.
class SmokedLogButtonView(
    context: Context,
    private val onHoldCompleted: () -> Unit,
    private val onDragged: (dx: Float, dy: Float) -> Unit,
    private val onDragFinished: () -> Unit,
) : View(context) {

    init {
        // This is a custom-drawn overlay asset, not a Material button.
        // Explicitly clear every platform-provided background/state layer so
        // no faint circle, pressed halo, elevation shadow, or default surface
        // appears behind the disc this view draws itself, on different
        // Android/OEM versions.
        background = null
        setBackgroundColor(Color.TRANSPARENT)
        elevation = 0f
        stateListAnimator = null
        clipToOutline = false
    }

    private val mark = BitmapFactory.decodeResource(resources, R.drawable.smoked_log_mark)

    /// The source asset is a single 1920x1920 bitmap with the butterfly in
    /// its upper-right region and the broken chain trailing off to the
    /// lower-left. There is no transparent gap between them to crop on, so
    /// this rect was picked by eye against the asset's actual pixels: wide
    /// enough to keep the butterfly's full wingspan, tight enough on the
    /// left edge (x=1050 of 1920) to exclude the chain and every stray
    /// fracture particle scattered ahead of it.
    private val butterflyOnlySrc = Rect(1050, 0, mark.width, mark.height)

    private val markPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        alpha = RESTING_ALPHA
    }
    private val tickPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(4f)
        strokeCap = Paint.Cap.ROUND
        color = ACCENT
    }

    private var holdStartedAt = 0L
    private var holding = false
    private var confirming = false
    private var dragging = false
        set(value) {
            if (field == value) return
            field = value
            invalidate()
        }
    private var downX = 0f
    private var downY = 0f

    /// The mark art faces right by default. When the button is snapped to
    /// the right edge it needs to face left instead, so the butterfly reads
    /// as looking back toward the screen — same intent as the in-app
    /// DraggableButterflyButton, which only ever sits with its artwork
    /// implicitly facing inward because it never mirrors. The overlay button
    /// can sit on either edge, so it has to flip explicitly.
    ///
    /// This also decides which physical half of the view onDraw treats as
    /// "the screen edge" side: facingRight true means the button sits on the
    /// left of the screen (nothing to its left), so it's the view's own
    /// *left* half that gets skipped at rest, matching the window snapped
    /// flush against the left edge. facingRight false is the mirror of that
    /// on the right edge.
    var facingRight: Boolean = true
        set(value) {
            if (field == value) return
            field = value
            invalidate()
        }

    private val bounds = RectF()

    private val ticker = object : Runnable {
        override fun run() {
            if (!holding) return
            if (progress() >= 1f) {
                completeHold()
                return
            }
            invalidate()
            postOnAnimation(this)
        }
    }

    private fun dp(value: Float) = value * resources.displayMetrics.density

    private fun progress(): Float {
        if (!holding) return 0f
        val elapsed = System.currentTimeMillis() - holdStartedAt
        return (elapsed.toFloat() / HOLD_DURATION_MS).coerceIn(0f, 1f)
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downX = event.rawX
                downY = event.rawY
                dragging = false
                startHold()
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - downX
                val dy = event.rawY - downY
                if (!dragging && (Math.abs(dx) > touchSlop() || Math.abs(dy) > touchSlop())) {
                    // Moving means they're repositioning the button, not
                    // answering it — abandon the hold so dragging it out of
                    // the way can never log a cigarette.
                    dragging = true
                    cancelHold()
                }
                if (dragging) {
                    onDragged(dx, dy)
                    downX = event.rawX
                    downY = event.rawY
                }
                return true
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (dragging) {
                    onDragFinished()
                } else {
                    // Released early: the ring unwinds and nothing is recorded.
                    cancelHold()
                }
                dragging = false
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    private fun touchSlop() = dp(8f)

    private fun startHold() {
        if (confirming) return
        holding = true
        holdStartedAt = System.currentTimeMillis()
        markPaint.alpha = ACTIVE_ALPHA
        postOnAnimation(ticker)
    }

    private fun cancelHold() {
        holding = false
        markPaint.alpha = RESTING_ALPHA
        invalidate()
    }

    private fun completeHold() {
        holding = false
        confirming = true
        markPaint.alpha = ACTIVE_ALPHA
        invalidate()
        onHoldCompleted()
        // Leave the tick up briefly so the user sees it was registered before
        // the button fades back to its resting state.
        postDelayed({
            confirming = false
            markPaint.alpha = RESTING_ALPHA
            invalidate()
        }, CONFIRM_HOLD_MS)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val inset = dp(6f)
        bounds.set(inset, inset, width - inset, height - inset)

        val markInset = dp(14f)
        val markRect = RectF(markInset, markInset, width - markInset, height - markInset)

        // The window is parked flush against whichever edge it's snapped to
        // (x=0 or x=screenWidth-buttonWidth, no margin), so the mark is
        // drawn across the view's full area either way — nothing needs to
        // be pushed toward one side or clipped to fake an off-screen half.
        // At rest (not dragging) only the butterfly quadrant of the source
        // asset is sampled — the chain reads as clutter sitting on top of
        // whatever app is underneath. Dragging shows the full asset (chain
        // included), since that's the moment the user is deliberately
        // looking at the control rather than glancing past it.
        val markSrc = if (dragging) null else butterflyOnlySrc
        if (facingRight) {
            canvas.drawBitmap(mark, markSrc, markRect, markPaint)
        } else {
            canvas.save()
            canvas.scale(-1f, 1f, width / 2f, height / 2f)
            canvas.drawBitmap(mark, markSrc, markRect, markPaint)
            canvas.restore()
        }
    }


    companion object {
        const val HOLD_DURATION_MS = 1000L
        private const val CONFIRM_HOLD_MS = 1_000L

        /// The asset itself has a transparent background. Keep the butterfly
        /// and chain marks fully opaque so they remain readable on the page.
        private const val RESTING_ALPHA = 255
        private const val ACTIVE_ALPHA = 255

        private val ACCENT = Color.parseColor("#00B8D4")
    }
}
