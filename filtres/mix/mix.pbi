
Macro Blend_entete_mix(nom , opt = 0) 
  Restore Blend_entete_mix_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\info[6] = "" ; efface l'option 6 (alpha)
  *FilterCtx\name = nom
  *FilterCtx\subtype = opt 
  If last_data < 0 : ProcedureReturn 0 : EndIf
  If *FilterCtx\image[2] = 0 : ProcedureReturn 0 : EndIf
  last_data - 1
EndMacro

Macro Blend_entete_mix2(nom , opt2 , opt = 0) 
  Restore Blend_entete_mix_data
  Protected last_data = Filter_InitAndValidate()
  *FilterCtx\name = nom
  *FilterCtx\subtype = opt 
  If last_data < 0 : ProcedureReturn 0 : EndIf
  If *FilterCtx\image[2] = 0 : ProcedureReturn 0 : EndIf
EndMacro


DataSection
  Blend_entete_mix_data:
  Data.s ""
  Data.s ""
  Data.i #FilterType_BlendModes
  Data.i 0
  
  Data.s "neg image 1"  
  Data.i 0,1,0
  Data.s "neg image 2" 
  Data.i 0,1,0
  Data.s "scaleX image 2" 
  Data.i 1,100,100
  Data.s "scaleX image 2"      
  Data.i 1,100,100
  Data.s "PosX image 2" 
  Data.i 0,200,100
  Data.s "PosY image 2"      
  Data.i 0,200,100
  Data.s "Alpha"      
  Data.i 0,255,128
  Data.s "XXX"
EndDataSection

Macro Blend_strat()

  Protected *src1.array32 = *FilterCtx\addr[0] ; source
  Protected *scr2.array32 = *FilterCtx\image[2]; mix 
  Protected *dst.array32  = *FilterCtx\addr[1] ; cible
  Protected lg      = *FilterCtx\image_lg[0]
  Protected ht      = *FilterCtx\image_ht[0]
  ; --- Optimisation : ratios pré-calculés (pour éviter divisions dans la boucle)
  Protected ratioX.f = *FilterCtx\image_lg[2] / (lg * (*FilterCtx\option[2] * 0.01))
  Protected ratioY.f = *FilterCtx\image_ht[2] / (ht * (*FilterCtx\option[3] * 0.01))
  ; --- Zone où appliquer le mix
  Protected posX_start = ((*FilterCtx\option[4] - 100) * lg) / 100
  Protected posY_start = ((*FilterCtx\option[5] - 100) * ht) / 100
  
  Protected posX_end = posX_start + ((lg * *FilterCtx\option[2]) / 100)
  Protected posY_end = posY_start + ((ht * *FilterCtx\option[3]) / 100)
  
  If posX_end > lg : posX_end = lg : EndIf
  If posY_end > ht : posY_end = ht : EndIf
  ; Multithreading : partition verticale
  macro_calul_tread(ht) 
  If thread_stop >= ht - 1 : thread_stop = ht - 1 : EndIf
  Protected x, y, pos, pos2
  Protected sx.f, sy.f
  Protected x1, y1
  Protected a, r, g, b
  Protected a1, r1, g1, b1
  Protected a2, r2, g2, b2
  For y = thread_start To thread_stop - 1
    ; Pré-calc pour la ligne (évite une multiplication dans la boucle x)
    Protected y_offset = y * lg
    sy = (y - posY_start) * ratioY
    For x = 0 To lg - 1
      pos = (y_offset + x); << 2
      getargb(*src1\l[pos], a1, r1, g1, b1)
      If *FilterCtx\option[0] : r1 = 255 - r1 : g1 = 255 - g1 : b1 = 255 - b1 : EndIf ; Option 0 : inversion source
      ; Test si pixel dans la zone
      If x >= posX_start And x < posX_end And y >= posY_start And y < posY_end
        sx = (x - posX_start) * ratioX
        x1 = Int(sx)
        y1 = Int(sy)
        pos2 = (y1 * *FilterCtx\image_lg[2] + x1); << 2
        getargb(*scr2\l[pos2], a2, r2, g2, b2)
        If *FilterCtx\option[1] : r2 = 255 - r2 : g2 = 255 - g2 : b2 = 255 - b2 : EndIf ; ; Option 1 : inversion du mix
EndMacro


Macro Blend_Stop()
        *dst\l[pos] = (a1 << 24) | (r << 16) | (g << 8) | b
      Else
        *dst\l[pos] = (a1 << 24) | (r1 << 16 ) | (g1 << 8) | b1
      EndIf
    Next
  Next
EndMacro




;**************

Macro macro_blend_sp0()
  Set_Source(source)
  Set_Cible(cible)
  Set_mix(mix)
  Set_Mask(mask)
  FilterCtx\option[0] = inv1
  FilterCtx\option[1] = inv2
  FilterCtx\option[2] = scx
  FilterCtx\option[3] = scy
  FilterCtx\option[4] = px
  FilterCtx\option[5] = py
  Blend_AdditiveEx(FilterCtx.FilterParams)
EndMacro

;-- 

Procedure Blend_additive_MT(*FilterCtx.FilterParams)
  Blend_strat()
  min(r , (r1 + r2) , 255)
  min(g , (g1 + g2) , 255)
  min(b , (b1 + b2) , 255)
  Blend_Stop()
EndProcedure

Procedure Blend_AdditiveEx(*FilterCtx.FilterParams)
  Blend_entete_mix("additive" , #Blend_Additive)
  Create_MultiThread_MT(@Blend_additive_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure

Procedure Blend_additive(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;-- **************
Procedure Blend_additive_inverted_MT(*FilterCtx.FilterParams)
  Blend_strat()
  Min(r , (r2 + (255 - r1)), 255)
  Min(g , (g2 + (255 - g1)), 255)
  Min(b , (b2 + (255 - b1)), 255)
  Blend_Stop()
EndProcedure

Procedure Blend_additive_invertedEx(*FilterCtx.FilterParams)
  Blend_entete_mix("additive_inverted" , #Blend_Additive)
  Create_MultiThread_MT(@Blend_additive_inverted_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_additive_inverted(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;-- **************
Procedure Blend_alphablend_MT(*FilterCtx.FilterParams)
  Protected alpha = *FilterCtx\option[6]
  clamp(alpha , 0 , 255)
  Protected inv_alpha = 255 - alpha
  Blend_strat()
  r = (r1 * alpha + r2 * inv_alpha + 127) / 255
  g = (g1 * alpha + g2 * inv_alpha + 127) / 255
  b = (b1 * alpha + b2 * inv_alpha + 127) / 255
  Blend_Stop()
EndProcedure

Procedure Blend_alphablendEx(*FilterCtx.FilterParams)
  Blend_entete_mix2("alphablend","alpa" , #Blend_Additive)
  Create_MultiThread_MT(@Blend_alphablend_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_alphablend(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_RMSColor_MT(*FilterCtx.FilterParams)
  ;Filtre2_QuadraticBlend
  ;Filtre2_SquaredAverage
  Blend_strat()
  r = (r1*r1*77 + r2*r2*77) >> 8
  g = (g1*g1*150 + g2*g2*150) >> 8
  b = (b1*b1*29 + b2*b2*29) >> 8
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_RMSColorEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_RMSColor")
  Create_MultiThread_MT(@Blend_RMSColor_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_RMSColor(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_And_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = r1 & r2
  g = g1 & g2
  b = b1 & b2
  Blend_Stop()
EndProcedure

Procedure Blend_AndEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_And")
  Create_MultiThread_MT(@Blend_And_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_And(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Average_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = (r1 + r2) >> 1
  g = (g1 + g2) >> 1
  b = (b1 + b2) >> 1
  Blend_Stop()
EndProcedure

Procedure Blend_AverageEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Average" ,#Blend_Additive)
  Create_MultiThread_MT(@Blend_Average_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Average(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_LightBlend_MT(*FilterCtx.FilterParams)
  ;Filtre2_IntensityBlend
  ;Filtre2_WeightedBlend
  Blend_strat()
  Protected v = r1 + g1 + b1
  r = ((r2 * v) + (r1 * v)) >> 11
  g = ((g2 * v) + (g1 * v)) >> 11
  b = ((b2 * v) + (b1 * v)) >> 11
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_LightBlendEx(*FilterCtx.FilterParams)
  Blend_entete_mix("LightBlend" , #Blend_Additive)
  Create_MultiThread_MT(@Blend_LightBlend_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_LightBlend(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_IntensityBoost_MT(*FilterCtx.FilterParams)
  ;Filtre2_PowerBlend
  ;Filtre2_Amplify
  Blend_strat()
  r = r2 + ((r1 * r1 * r2) >> 16)
  g = g2 + ((g1 * g1 * g2) >> 16)
  b = b2 + ((b1 * b1 * b2) >> 16)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_IntensityBoostEx(*FilterCtx.FilterParams)
  Blend_entete_mix("IntensityBoost" , #Blend_Additive)
  Create_MultiThread_MT(@Blend_IntensityBoost_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_IntensityBoost(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_BrushUp_MT(*FilterCtx.FilterParams)
  Blend_strat()
  Protected l1 = (r1 * 1225 + g1 * 2405 + b1 * 466) >> 12
  Protected l2 = (r2 * 1225 + g2 * 2405 + b2 * 466) >> 12
  r = (r1 * l2 + r2 * l1) >> 9
  g = (g1 * l2 + g2 * l1) >> 9
  b = (b1 * l2 + b2 * l1) >> 9
  ;Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_BrushUpEx(*FilterCtx.FilterParams)
  Blend_entete_mix("BrushUp" , #Blend_Additive)
  Create_MultiThread_MT(@Blend_BrushUp_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_BrushUp(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Burn_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = 256 - ((256 - r2) << 8) / (r1 + 1)
  g = 256 - ((256 - g2) << 8) / (g1 + 1)
  b = 256 - ((256 - b2) << 8) / (b1 + 1)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_BurnEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Burn" , #Blend_Subtractive)
  Create_MultiThread_MT(@Blend_Burn_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Burn(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_SubtractiveDodge_MT(*FilterCtx.FilterParams)
  ;Filtre2_LinearDodge
  Blend_strat()
  Max(r , 0, (r2 - 255 + r1))
  Max(g , 0, (g2 - 255 + g1))
  Max(b , 0, (b2 - 255 + b1))
  Min(r , 255, (r2 - r))
  Min(g , 255, (g2 - g))
  Min(b , 255, (b2 - b))
  Blend_Stop()
EndProcedure

Procedure Blend_SubtractiveDodgeEx(*FilterCtx.FilterParams)
  Blend_entete_mix("SubtractiveDodge" , #Blend_Subtractive)
  Create_MultiThread_MT(@Blend_SubtractiveDodge_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_SubtractiveDodge(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_ColorBurn_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = 0 : g = 0 : b = 0
  If r1 > 0 : r = 255 - (((255 - r2) << 8) / r1) : EndIf
  If g1 > 0 : g = 255 - (((255 - g2) << 8) / g1) : EndIf
  If b1 > 0 : b = 255 - (((255 - b2) << 8) / b1) : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_ColorBurnEx(*FilterCtx.FilterParams)
  ; Partie en-tête + appel multi-thread
  Blend_entete_mix("ColorBurn" , #Blend_Subtractive)
  Create_MultiThread_MT(@Blend_ColorBurn_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_ColorBurn(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_ColorDodge_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = 0 : g = 0 : b = 0
  If r1 < 255 : Min(r, ((r2 << 8) / (255 - r1)), 255) : EndIf
  If g1 < 255 : Min(g, ((g2 << 8) / (255 - g1)), 255) : EndIf
  If b1 < 255 : Min(b, ((b2 << 8) / (255 - b1)), 255) : EndIf
  Blend_Stop()
EndProcedure

Procedure Blend_ColorDodgeEx(*FilterCtx.FilterParams)
  Blend_entete_mix("ColorDodge" , #Blend_Subtractive)
  Create_MultiThread_MT(@Blend_ColorDodge_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_ColorDodge(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Contrast_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = 127 + ((r2 - 127) * r1) / 127
  g = 127 + ((g2 - 127) * g1) / 127
  b = 127 + ((b2 - 127) * b1) / 127
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_ContrastEX(*FilterCtx.FilterParams)
  Blend_entete_mix("Contrast" , #Blend_Contrast)
  Create_MultiThread_MT(@Blend_Contrast_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Contrast(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Cosine_MT(*FilterCtx.FilterParams)
  Protected Dim CosLUT(256) , j
  For j = 0 To 255 : CosLUT(j) = Int(Abs(Cos(j * 3.14159265 / 255)) * 255) : Next
  Blend_strat()
  r = (CosLUT(r1) * r2) >> 8
  g = (CosLUT(g1) * g2) >> 8
  b = (CosLUT(b1) * b2) >> 8
  Clamp_RGB(r, g, b)
  Blend_Stop()
  FreeArray(CosLUT())
EndProcedure

Procedure Blend_CosineEX(*FilterCtx.FilterParams)
  Blend_entete_mix("Cosine" , #Blend_Contrast)
  Create_MultiThread_MT(@Blend_Cosine_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Cosine(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_CrossFading_MT(*FilterCtx.FilterParams)
  Protected fading = *FilterCtx\option[6]
  Blend_strat()
  r = (r1 * fading + r2 * (255 - fading)) >> 8
  g = (g1 * fading + g2 * (255 - fading)) >> 8
  b = (b1 * fading + b2 * (255 - fading)) >> 8
  Blend_Stop()
EndProcedure

Procedure Blend_CrossFadingEx(*FilterCtx.FilterParams)
  Blend_entete_mix2("CrossFading","fading" , #Blend_Contrast)
  Create_MultiThread_MT(@Blend_CrossFading_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_CrossFading(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_InverseMultiply_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r1 = 255 - r1
  g1 = 255 - g1
  b1 = 255 - b1
  r2 = 255 - r2
  g2 = 255 - g2
  b2 = 255 - b2
  r = (r1 * r1 * r2) / 65025
  g = (g1 * g1 * g2) / 65025
  b = (b1 * b1 * b2) / 65025
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_InverseMultiplyEX(*FilterCtx.FilterParams)
  Blend_entete_mix("InverseMultiply" , #Blend_Multiply)
  Create_MultiThread_MT(@Blend_InverseMultiply_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_InverseMultiply(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Darken_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = r2
  g = g2
  b = b2
  If r1 < r2 : r = r1 : EndIf
  If g1 < g2 : g = g1 : EndIf
  If b1 < b2 : b = b1 : EndIf
  Blend_Stop()
EndProcedure

Procedure Blend_DarkenEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Darken" , #Blend_Multiply)
  Create_MultiThread_MT(@Blend_Darken_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Darken(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_SubtractiveBlend_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = r2 - (255 - ((r1 * r2) >> 8))
  g = g2 - (255 - ((g1 * g2) >> 8))
  b = b2 - (255 - ((b1 * b2) >> 8))
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_SubtractiveBlendEx(*FilterCtx.FilterParams)
  Blend_entete_mix("SubtractiveBlend" , #Blend_Subtractive)
  Create_MultiThread_MT(@Blend_SubtractiveBlend_MT())
  mask_update(*FilterCtx.FilterParams , last_data) 
EndProcedure
Procedure Blend_SubtractiveBlend(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Difference_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = Abs(r1 - r2)
  g = Abs(g1 - g2)
  b = Abs(b1 - b2)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_DifferenceEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Difference" , #Blend_Multiply)
  Create_MultiThread_MT(@Blend_Difference_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Difference(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Div_MT(*FilterCtx.FilterParams)
  Protected m = *FilterCtx\option[6]
  Blend_strat()
  r = r1 * m / (r2 + 1)
  g = g1 * m / (g2 + 1)
  b = b1 * m / (b2 + 1)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_DivEx(*FilterCtx.FilterParams)
  Blend_entete_mix2("Div","mul" , #Blend_Multiply)
  Create_MultiThread_MT(@Blend_Div_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Div(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_SoftAdd_MT(*FilterCtx.FilterParams)
  ;Filtre2_ScreenBlend
  ;Filtre2_LightenBlend
  Blend_strat()
  r = (r1 + r2) - ((r1 * r2) >> 7)
  g = (g1 + g2) - ((g1 * g2) >> 7)
  b = (b1 + b2) - ((b1 * b2) >> 7)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_SoftAddEx(*FilterCtx.FilterParams)
  Blend_entete_mix("SoftAdd" , #Blend_Additive)
  Create_MultiThread_MT(@Blend_SoftAdd_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_SoftAdd(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_SoftLightBoost_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = r2 + r1 * (r1 / 127.5 - 1)
  g = g2 + g1 * (g1 / 127.5 - 1)
  b = b2 + b1 * (b1 / 127.5 - 1)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_SoftLightBoostEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_SoftLightBoost")
  Create_MultiThread_MT(@Blend_SoftLightBoost_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_SoftLightBoost(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Exponentiale_MT(*FilterCtx.FilterParams)
  Protected Dim ExpLUT(256) , j
  For j = 0 To 255
    ExpLUT(j) = Int(Pow(255, j / 255.0) + 0.5)  ; valeur entière arrondie
    If ExpLUT(j) > 255 : ExpLUT(j) = 255 : EndIf
  Next
  Blend_strat()
  r = (ExpLUT(r1) * r2) >> 8
  g = (ExpLUT(g1) * g2) >> 8
  b = (ExpLUT(b1) * b2) >> 8
  Clamp_RGB(r, g, b)
  Blend_Stop()
  FreeArray(ExpLUT())
EndProcedure

Procedure Blend_ExponentialeEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Exponentiale" , #Blend_Multiply)
  Create_MultiThread_MT(@Blend_Exponentiale_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Exponentiale(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Fade_MT(*FilterCtx.FilterParams)
  Protected Dim SumLUT(766) , j
  For j = 0 To 765 : SumLUT(j) = j : Next
  Blend_strat()
  Protected s2 = SumLUT(r2 + g2 + b2)
  Protected s1 = SumLUT(r1 + g1 + b1)
  r = ((r2 + s2) * (r1 + s1)) >> 12
  g = ((g2 + s2) * (g1 + s1)) >> 12
  b = ((b2 + s2) * (b1 + s1)) >> 12
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_FadeEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Fade")
  Create_MultiThread_MT(@Blend_Fade_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Fade(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Fence_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = (r2 * (r1 + r2)) >> 9 
  g = (g2 * (g1 + g2)) >> 9
  b = (b2 * (b1 + b2)) >> 9
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_FenceEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Fence")
  Create_MultiThread_MT(@Blend_Fence_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Fence(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Freeze_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = 255 - ((255 - r1) * (255 - r1)) / (r2 + 1)
  g = 255 - ((255 - g1) * (255 - g1)) / (g2 + 1)
  b = 255 - ((255 - b1) * (255 - b1)) / (b2 + 1)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_FreezeEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Freeze")
  Create_MultiThread_MT(@Blend_Freeze_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Freeze(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Glow_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = (r2 * r2) / ((255 - r1) + 1)
  g = (g2 * g2) / ((255 - g1) + 1)
  b = (b2 * b2) / ((255 - b1) + 1)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_GlowEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Glow")
  Create_MultiThread_MT(@Blend_Glow_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Glow(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_HardContrast_MT(*FilterCtx.FilterParams)
  Blend_strat()
  If r2 > 127 : r = r2 + r1 - 127 : Else : r = r2 - r1 + 127 : EndIf
  If g2 > 127 : g = g2 + g1 - 127 : Else : g = g2 - g1 + 127 : EndIf
  If b2 > 127 : b = b2 + b1 - 127 : Else : b = b2 - b1 + 127 : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_HardContrastEx(*FilterCtx.FilterParams)
  Blend_entete_mix("HardContrast" , #Blend_Contrast)
  Create_MultiThread_MT(@Blend_HardContrast_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_HardContrast(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Hardlight_MT(*FilterCtx.FilterParams)
  Blend_strat()
  If r2 < 128 : r = (r1 * r2) >> 7 : Else : r = 255 - ((255 - r1) * (255 - r2) >> 7) : EndIf
  If g2 < 128 : g = (g1 * g2) >> 7 : Else : g = 255 - ((255 - g1) * (255 - g2) >> 7) : EndIf
  If b2 < 128 : b = (b1 * b2) >> 7 : Else : b = 255 - ((255 - b1) * (255 - b2) >> 7) : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_HardlightEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Hardlight")
  Create_MultiThread_MT(@Blend_Hardlight_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Hardlight(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_TanBlend_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = r2 + Tan(r1 * 0.706125 - 90) * 128  
  g = g2 + Tan(g1 * 0.706125 - 90) * 128
  b = b2 + Tan(b1 * 0.706125 - 90) * 128
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_TanBlendEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_TanBlend")
  Create_MultiThread_MT(@Blend_TanBlend_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_TanBlend(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_HardlTangent_MT(*FilterCtx.FilterParams)
  Protected Dim tab(255) , j , c
  ;For j = 0 To 255 : tab(j) = Tan(j * 180 / 256 - 90) * 128 : Next
  c = 4 ; 8 ou 16
  For j = 0 To 255 : tab(j) = TanH((j - 128) / c) * 128 : Next
  Blend_strat()
  r = r2 + tab(r1)
  g = g2 + tab(g1)
  b = b2 + tab(b1)
  Clamp_RGB(r, g, b)
  Blend_Stop()
  FreeArray(tab())
EndProcedure

Procedure Blend_HardlTangentEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_HardlTangent")
  Create_MultiThread_MT(@Blend_HardlTangent_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_HardlTangent(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Heat_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = 255 - ((255 - r2) * (255 - r2)) / (r1 + 1)
  g = 255 - ((255 - g2) * (255 - g2)) / (g1 + 1)
  b = 255 - ((255 - b2) * (255 - b2)) / (b1 + 1)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_HeatEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Heat")
  Create_MultiThread_MT(@Blend_Heat_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Heat(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_InHale_MT(*FilterCtx.FilterParams)
  Protected Dim tab(255) , j
  For j = 0 To 255 : tab(j) = (255 - j) * ((255 - j) / 127.5 - 1) : Clamp(tab(j), 0, 255) : Next
  Blend_strat()
  r = r2 - tab(r1)
  g = g2 - tab(g1)
  b = b2 - tab(b1)
  Clamp_RGB(r, g, b)
  Blend_Stop()
  FreeArray(tab())
EndProcedure

Procedure Blend_InHaleEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_InHale")
  Create_MultiThread_MT(@Blend_InHale_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_InHale(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Intensify_MT(*FilterCtx.FilterParams)
  Protected Dim tab(256) , j
  For j = 0 To 255 : tab(j) = 64 - Cos(j * 3.14 / 255) * 64 : Next
  Blend_strat()
  r = r2 + ((r1 * r2) >> 8)
  g = g2 + ((g1 * g2) >> 8)
  b = b2 + ((b1 * b2) >> 8)
  Clamp_RGB(r, g, b)
  Blend_Stop()
  FreeArray(tab())
EndProcedure

Procedure Blend_IntensifyEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Intensify")
  Create_MultiThread_MT(@Blend_Intensify_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Intensify(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_CosBlend_MT(*FilterCtx.FilterParams)
  Protected Dim tab(256) , j
  For j = 0 To 255 : tab(j) = 64 - Cos(j * 3.14 / 255) * 64 : Next
  Blend_strat()
  r = tab(r1) + tab(r2)
  g = tab(g1) + tab(g2)
  b = tab(b1) + tab(b2)
  Clamp_RGB(r, g, b)
  Blend_Stop()
  FreeArray(tab())
EndProcedure

Procedure Blend_CosBlendEx(*FilterCtx.FilterParams)
  Blend_entete_mix("CosBlend" , #Blend_Contrast)
  Create_MultiThread_MT(@Blend_CosBlend_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_CosBlend(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
;-- a modifier
Procedure Blend_Interpolation_MT(*FilterCtx.FilterParams)
  Protected Dim tab(256) , j
  For j = 0 To 255 : tab(j) = 64 - Cos(j * 3.14159265 / 255) * 64 : Next
  Protected fading = *FilterCtx\option[0]
  Blend_strat() 
  r = (tab(r1) * fading + tab(r2) * (255 - fading)) >> 8
  g = (tab(g1) * fading + tab(g2) * (255 - fading)) >> 8
  b = (tab(b1) * fading + tab(b2) * (255 - fading)) >> 8
  Clamp_RGB(r, g, b)
  Blend_Stop()
  FreeArray(tab())
EndProcedure

Procedure Blend_InterpolationEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Interpolation")
  Create_MultiThread_MT(@Blend_Interpolation_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Interpolation(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_InvBurn_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = 0 : g = 0 : b = 0
  If r1 > 0 : r = 255 - (255 - r2) / r1 : EndIf
  If g1 > 0 : g = 255 - (255 - g2) / g1 : EndIf
  If b1 > 0 : b = 255 - (255 - b2) / b1 : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_InvBurnEx(*FilterCtx.FilterParams)
  Blend_entete_mix("InvBurn" , #Blend_Subtractive)
  Create_MultiThread_MT(@Blend_InvBurn_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_InvBurn(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_InvColorBurn_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = 0 : g = 0 : b = 0
  If r1 > 0 : r = 255 - (((255 - r2) << 8) / r1) : EndIf
  If g1 > 0 : g = 255 - (((255 - g2) << 8) / g1) : EndIf
  If b1 > 0 : b = 255 - (((255 - b2) << 8) / b1) : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_InvColorBurnEx(*FilterCtx.FilterParams)
  Blend_entete_mix("InvColorBurn" , #Blend_Subtractive)
  Create_MultiThread_MT(@Blend_InvColorBurn_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_InvColorBurn(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_InvColorDodge_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = 255 : g = 255 : b = 255
  If r1 < 255 : r = (r2 << 8) / (255 - r1) : EndIf
  If g1 < 255 : g = (g2 << 8) / (255 - g1) : EndIf
  If b1 < 255 : b = (b2 << 8) / (255 - b1) : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_InvColorDodgeEx(*FilterCtx.FilterParams)
  Blend_entete_mix("InvColorDodge" , #Blend_Subtractive)
  Create_MultiThread_MT(@Blend_InvColorDodge_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_InvColorDodge(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_InvDodge_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = 255 : g = 255 : b = 255
  If r1 < 255 : r = r2 / (255 - r1) : EndIf
  If g1 < 255 : g = g2 / (255 - g1) : EndIf
  If b1 < 255 : b = b2 / (255 - b1) : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_InvDodgeEx(*FilterCtx.FilterParams)
  Blend_entete_mix("InvDodge" , #Blend_Subtractive)
  Create_MultiThread_MT(@Blend_InvDodge_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_InvDodge(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Lighten_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = r2 : g = g2 : b = b2
  If r1 > r2 : r = r1 : EndIf
  If g1 > g2 : g = g1 : EndIf
  If b1 > b2 : b = b1 : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_LightenEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Lighten" ,#Blend_Additive)
  Create_MultiThread_MT(@Blend_Lighten_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure                                    
Procedure Blend_Lighten(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_LinearBurn_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = r1 + r2
  g = g1 + g2
  b = b1 + b2
  If r < 256 : r = 0 : Else : r = r - 255 : EndIf
  If g < 256 : g = 0 : Else : g = g - 255 : EndIf
  If b < 256 : b = 0 : Else : b = b - 255 : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure                               

Procedure Blend_LinearBurnEx(*FilterCtx.FilterParams)
  Blend_entete_mix("LinearBurn" , #Blend_Subtractive)
  Create_MultiThread_MT(@Blend_LinearBurn_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure  
Procedure Blend_LinearBurn(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_LinearLight_MT(*FilterCtx.FilterParams)
  Protected Dim comps(2)
  Protected Dim src1(2), Dim src2(2)
  Protected k
  Blend_strat()
  src1(0)=r1 : src1(1)=g1 : src1(2)=b1
  src2(0)=r2 : src2(1)=g2 : src2(2)=b2
  For k = 0 To 2
    If src1(k) < 128 
      comps(k) = src2(k) + src1(k)*2
    Else
      comps(k) = src2(k) + (src1(k)-128)*2
    EndIf
    Clamp(comps(k), 0, 255)
  Next
  r = comps(0)
  g = comps(1)
  b = comps(2)
  Clamp_RGB(r, g, b)
  Blend_Stop()
  FreeArray(comps())
  FreeArray(src1())
  FreeArray(src2())
EndProcedure

Procedure Blend_LinearLightEx(*FilterCtx.FilterParams)
  Blend_entete_mix("LinearLight" , #Blend_Additive)
  Create_MultiThread_MT(@Blend_LinearLight_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_LinearLight(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Logarithmic_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = 255 * (Log(r1 + 1) + Log(r2 + 1)) / (2 * Log(256))
  g = 255 * (Log(g1 + 1) + Log(g2 + 1)) / (2 * Log(256))
  b = 255 * (Log(b1 + 1) + Log(b2 + 1)) / (2 * Log(256))
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_LogarithmicEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Logarithmic")
  Create_MultiThread_MT(@Blend_Logarithmic_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Logarithmic(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Mean_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = (r1 + r2) >> 1
  g = (g1 + g2) >> 1
  b = (b1 + b2) >> 1
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_MeanEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Mean")
  Create_MultiThread_MT(@Blend_Mean_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Mean(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_ColorVivify_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = r2 + r1 - (g1 + b1) >> 1
  g = g2 + g1 - (r1 + b1) >> 1
  b = b2 + b1 - (g1 + r1) >> 1
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_ColorVivifyEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_ColorVivify")
  Create_MultiThread_MT(@Blend_ColorVivify_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_ColorVivify(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Multiply_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = (r1 * r2) >> 8
  g = (g1 * g2) >> 8
  b = (b1 * b2) >> 8
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_MultiplyEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Multiply" , #Blend_Multiply)
  Create_MultiThread_MT(@Blend_Multiply_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Multiply(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Negation_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = 255 - Abs(255 - r1 - r2)
  g = 255 - Abs(255 - g1 - g2)
  b = 255 - Abs(255 - b1 - b2)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_NegationEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Negation" , #Blend_Multiply)
  Create_MultiThread_MT(@Blend_Negation_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure                  
Procedure Blend_Negation(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_PinLight_MT(*FilterCtx.FilterParams)
  Blend_strat()
  If r1 < 128 : Min(r , r2, (2 * r1)) : Else : Max(r , r2, (2 * (r1 - 128))) : EndIf
  If g1 < 128 : Min(g , g2, (2 * g1)) : Else : Max(g , g2, (2 * (g1 - 128))) : EndIf
  If b1 < 128 : Min(b , b2, (2 * b1)) : Else : Max(b , b2, (2 * (b1 - 128))) : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_PinLightEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_PinLight")
  Create_MultiThread_MT(@Blend_PinLight_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_PinLight(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Or_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = r1 | r2
  g = g1 | g2
  b = b1 | b2
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_OrEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Or")
  Create_MultiThread_MT(@Blend_Or_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Or(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Overlay_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = (r1 * r2) >> 7
  g = (g1 * g2) >> 7
  b = (b1 * b2) >> 7
  If r1 >= 128 : r = 255 - ((255 - r1) * (255 - r2) >> 7) : EndIf
  If g1 >= 128 : g = 255 - ((255 - g1) * (255 - g2) >> 7) : EndIf
  If b1 >= 128 : b = 255 - ((255 - b1) * (255 - b2) >> 7) : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_OverlayEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Overlay")
  Create_MultiThread_MT(@Blend_Overlay_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Overlay(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Pegtop_soft_light_MT(*FilterCtx.FilterParams)
  Blend_strat()
  Protected c = (r1 * r2) >> 8
  r = c + r1 * (255 - ((255 - r1) * (255 - r2) >> 8) - c) >> 8
  c = (g1 * g2) >> 8
  g = c + g1 * (255 - ((255 - g1) * (255 - g2) >> 8) - c) >> 8
  c = (b1 * b2) >> 8
  b = c + b1 * (255 - ((255 - b1) * (255 - b2) >> 8) - c) >> 8
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Pegtop_soft_lightEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Pegtop_soft_light")
  Create_MultiThread_MT(@Blend_Pegtop_soft_light_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Pegtop_soft_light(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_quadritic_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = 255
  If r2 <> 255 : r = r1 * r1 / (255 - r2) : EndIf
  g = 255
  If g2 <> 255 : g = g1 * g1 / (255 - g2) : EndIf
  b = 255
  If b2 <> 255 : b = b1 * b1 / (255 - b2) : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_quadriticEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_quadritic")
  Create_MultiThread_MT(@Blend_quadritic_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_quadritic(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Screen_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = 255 - ((255 - r1) * (255 - r2) >> 8)
  g = 255 - ((255 - g1) * (255 - g2) >> 8)
  b = 255 - ((255 - b1) * (255 - b2) >> 8)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_ScreenEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Screen" , #Blend_Additive)
  Create_MultiThread_MT(@Blend_Screen_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure   
Procedure Blend_Screen(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_SoftColorBurn_MT(*FilterCtx.FilterParams)
  Blend_strat()
  ; Calcul soft burn pour chaque composante
  If r1 + r2 < 256
    If r1 = 255
      r = 255
    Else
      r = (r2 << 7) / (255 - r1)
      If r > 255 : r = 255 : EndIf
    EndIf
  Else
    r = 255 - (((255 - r1) << 7) / r2)
    If r < 0 : r = 0 : EndIf
  EndIf
  
  If g1 + g2 < 256
    If g1 = 255
      g = 255
    Else
      g = (g2 << 7) / (255 - g1)
      If g > 255 : g = 255 : EndIf
    EndIf
  Else
    g = 255 - (((255 - g1) << 7) / g2)
    If g < 0 : g = 0 : EndIf
  EndIf
  
  If b1 + b2 < 256
    If b1 = 255
      b = 255
    Else
      b = (b2 << 7) / (255 - b1)
      If b > 255 : b = 255 : EndIf
    EndIf
  Else
    b = 255 - (((255 - b1) << 7) / b2)
    If b < 0 : b = 0 : EndIf
  EndIf
  
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_SoftColorBurnEx(*FilterCtx.FilterParams)
  Blend_entete_mix("SoftColorBurn" , #Blend_Subtractive)
  Create_MultiThread_MT(@Blend_SoftColorBurn_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_SoftColorBurn(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_SoftColorDodge_MT(*FilterCtx.FilterParams)
  Blend_strat()
  ; Composante rouge
  If r1 + r2 < 256
    If r2 = 255
      r = 255
    Else
      r = (r1 << 7) / (255 - r2)
      If r > 255 : r = 255 : EndIf
    EndIf
  Else
    r = 255 - (((255 - r2) << 7) / r1)
    If r < 0 : r = 0 : EndIf
  EndIf
  
  ; Composante verte
  If g1 + g2 < 256
    If g2 = 255
      g = 255
    Else
      g = (g1 << 7) / (255 - g2)
      If g > 255 : g = 255 : EndIf
    EndIf
  Else
    g = 255 - (((255 - g2) << 7) / g1)
    If g < 0 : g = 0 : EndIf
  EndIf
  
  ; Composante bleue
  If b1 + b2 < 256
    If b2 = 255
      b = 255
    Else
      b = (b1 << 7) / (255 - b2)
      If b > 255 : b = 255 : EndIf
    EndIf
  Else
    b = 255 - (((255 - b2) << 7) / b1)
    If b < 0 : b = 0 : EndIf
  EndIf
  
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_SoftColorDodgeEx(*FilterCtx.FilterParams)
  Blend_entete_mix("SoftColorDodge" , #Blend_Subtractive)
  Create_MultiThread_MT(@Blend_SoftColorDodge_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure             
Procedure Blend_SoftColorDodge(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_SoftLight_MT(*FilterCtx.FilterParams)
  Protected k
  Blend_strat()
  Protected Dim src1(2), Dim src2(2), Dim res(2)
  src1(0)=r1 : src1(1)=g1 : src1(2)=b1
  src2(0)=r2 : src2(1)=g2 : src2(2)=b2 
  For k = 0 To 2
    Protected c = (src1(k) * src2(k)) >> 8
    res(k) = c + src1(k) * (255 - (((255 - src1(k)) * (255 - src2(k))) >> 8) - c) >> 8
  Next
  r = res(0) : g = res(1) : b = res(2)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_SoftLightEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_SoftLight")
  Create_MultiThread_MT(@Blend_SoftLight_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_SoftLight(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_SoftOverlay_MT(*FilterCtx.FilterParams)
  Blend_strat()
  If r1 < 128
    r = (r1 * r2) >> 7
  Else
    r = 255 - ((255 - r1) * (255 - r2) >> 7)
  EndIf

  If g1 < 128
    g = (g1 * g2) >> 7
  Else
    g = 255 - ((255 - g1) * (255 - g2) >> 7)
  EndIf

  If b1 < 128
    b = (b1 * b2) >> 7
  Else
    b = 255 - ((255 - b1) * (255 - b2) >> 7)
  EndIf
  
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_SoftOverlayEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_SoftOverlay")
  Create_MultiThread_MT(@Blend_SoftOverlay_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure                 
Procedure Blend_SoftOverlay(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Stamp_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = (r1 + r2 * 2) - 256
  g = (g1 + g2 * 2) - 256
  b = (b1 + b2 * 2) - 256
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_StampEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Stamp")
  Create_MultiThread_MT(@Blend_Stamp_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Stamp(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Subtractive_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = (r1 + r2) - 256
  g = (g1 + g2) - 256
  b = (b1 + b2) - 256
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_SubtractiveEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Subtractive" , #Blend_Subtractive)
  Create_MultiThread_MT(@Blend_Subtractive_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure                  
Procedure Blend_Subtractive(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure

;**************
Procedure Blend_Xor_MT(*FilterCtx.FilterParams)
  Blend_strat()
  r = r1 ! r2
  g = g1 ! g2
  b = b1 ! b2
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_XorEx(*FilterCtx.FilterParams)
  Blend_entete_mix("Filtre2_Xor")
  Create_MultiThread_MT(@Blend_Xor_MT())
  mask_update(*FilterCtx.FilterParams , last_data)
EndProcedure
Procedure Blend_Xor(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) : macro_blend_sp0() : EndProcedure


; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 196
; FirstLine = 182
; Folding = --------------------------------
; Markers = 1144
; EnableAsm
; EnableThread
; EnableXP