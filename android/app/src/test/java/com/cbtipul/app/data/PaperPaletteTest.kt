package com.cbtipul.app.data
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import com.cbtipul.app.ui.theme.*
import org.junit.Assert.*
import org.junit.Test
class PaperPaletteTest {
 private fun contrast(a: Color, b: Color): Float {
  val x=a.luminance(); val y=b.luminance()
  return (maxOf(x,y)+.05f)/(minOf(x,y)+.05f)
 }
 @Test fun paperTextAndActionsHaveAccessibleContrast() {
  val c=cbTipulColors(false)
  for (surface in listOf(c.base,c.surface,c.elevated)) {
   for (ink in listOf(c.textBright,c.textBody,c.textFaint)) assertTrue(contrast(ink,surface)>=4.5f)
  }
  assertTrue(contrast(c.textOnAccent,c.accentFill)>=4.5f)
 }
 @Test fun everyHistoryBandKeepsLegibleTextInBothModes() {
  for (paper in listOf(true,false)) for (fill in QuestionnaireHistoryColors.bands(paper)+QuestionnaireHistoryColors.background(paper)) {
   assertTrue(contrast(QuestionnaireHistoryColors.foreground(paper),fill)>=4.5f)
  }
 }
 @Test fun darkIdentityRemainsSeparate() {
  assertEquals(DarkPalette.base,cbTipulColors(true).base)
  assertEquals(DarkPalette.gold,cbTipulColors(true).accentFill)
  assertNotEquals(cbTipulColors(false).accentFill,cbTipulColors(false).success)
 }
}
