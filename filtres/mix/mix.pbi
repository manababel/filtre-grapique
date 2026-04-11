
Macro Blend_entete_mix(nom , opt1 = 0) 
  If param\info_active
    param\typ = #FilterType_BlendModes
    *param\subtype = opt1
    param\name = nom
    param\remarque = ""         
    param\info[0] = "neg image 1"
    param\info[1] = "neg image 2"
    param\info[2] = "scaleX image 2"
    param\info[3] = "scaleX image 2"
    param\info[4] = "PosX image 2"
    param\info[5] = "Posy image 2"
    param\info[6] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 1  : param\info_data(0,2) = 0 
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1  : param\info_data(1,2) = 0 
    param\info_data(2,0) = 0 : param\info_data(2,1) = 100  : param\info_data(2,2) = 100 
    param\info_data(3,0) = 0 : param\info_data(3,1) = 100  : param\info_data(3,2) = 100
    param\info_data(4,0) = 0 : param\info_data(4,1) = 200  : param\info_data(4,2) = 100
    param\info_data(5,0) = 0 : param\info_data(5,1) = 200  : param\info_data(5,2) = 100
    param\info_data(6,0) = 0 : param\info_data(6,1) = 2  : param\info_data(6,2) = 0
    ProcedureReturn
  EndIf
  
  Protected *tempo
  If *param\source = *param\cible
    *tempo = AllocateMemory(*param\lg * *param\ht * 4)
    If Not *tempo : ProcedureReturn : EndIf
    CopyMemory(*param\source , *tempo , *param\lg * *param\ht * 4)
    *param\addr[0] = *tempo
  Else
    *param\addr[0] = *param\source
  EndIf
  
  *param\addr[1] = *param\mix
  Protected var = 6 ; = "Masque binaire"
EndMacro

Macro Blend_entete_mix2(nom , op1 , opt2 = 0) 
  If param\info_active
    param\typ = #FilterType_BlendModes
    *param\subtype = opt2
    param\name = nom
    param\remarque = ""   
    param\info[0] = "neg image 1"
    param\info[1] = "neg image 2"
    param\info[2] = "scaleX image 2"
    param\info[3] = "scaleX image 2"
    param\info[4] = "PosX image 2"
    param\info[5] = "Posy image 2"
    param\info[6] = op1   
    param\info[7] = "Masque binaire" 
    param\info_data(0,0) = 0 : param\info_data(0,1) = 1  : param\info_data(0,2) = 0 
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1  : param\info_data(1,2) = 0 
    param\info_data(2,0) = 0 : param\info_data(2,1) = 100  : param\info_data(2,2) = 100 
    param\info_data(3,0) = 0 : param\info_data(3,1) = 100  : param\info_data(3,2) = 100
    param\info_data(4,0) = 0 : param\info_data(4,1) = 200  : param\info_data(4,2) = 100
    param\info_data(5,0) = 0 : param\info_data(5,1) = 200  : param\info_data(5,2) = 100
    param\info_data(6,0) = 0 : param\info_data(6,1) = 255  : param\info_data(6,2) = 128
    param\info_data(7,0) = 0 : param\info_data(7,1) = 2  : param\info_data(7,2) = 0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\mix = 0 Or  *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected *tempo
  If *param\source = *param\cible
    *tempo = AllocateMemory(*param\lg * *param\ht * 4)
    If Not *tempo : ProcedureReturn : EndIf
    CopyMemory(*param\source , *tempo , *param\lg * *param\ht * 4)
    *param\addr[0] = *tempo
  Else
    *param\addr[0] = *param\source
  EndIf
  
  *param\addr[1] = *param\mix
  Protected var = 7 ; = "Masque binaire"
EndMacro




Macro Blend_strat()

  Protected *src1.Long    = *param\source
  Protected *src2.Long    = *param\mix
  Protected *dst.Long     = *param\cible
  
  Protected lg      = *param\lg
  Protected ht      = *param\ht
  Protected lg_mix  = *param\lg_mix
  Protected ht_mix  = *param\ht_mix

  Protected scale_x = *param\option[2]
  Protected scale_y = *param\option[3]

  ; --- Optimisation : ratios pré-calculés (pour éviter divisions dans la boucle)
  Protected ratioX.f = lg_mix / (lg * (scale_x * 0.01))
  Protected ratioY.f = ht_mix / (ht * (scale_y * 0.01))

  ; --- Zone où appliquer le mix
  Protected posX_start = ((*param\option[4] - 100) * lg) / 100
  Protected posY_start = ((*param\option[5] - 100) * ht) / 100

  Protected lg2 = (lg * scale_x) / 100
  Protected ht2 = (ht * scale_y) / 100

  Protected posX_end = posX_start + lg2
  Protected posY_end = posY_start + ht2

  If posX_end > lg : posX_end = lg : EndIf
  If posY_end > ht : posY_end = ht : EndIf
  
  ; Multithreading : partition verticale
  Protected startY = (*param\thread_pos * ht) / *param\thread_max
  Protected stopY  = ((*param\thread_pos + 1) * ht) / *param\thread_max - 1
  If stopY >= ht - 1 : stopY = ht - 1 : EndIf

  Protected x, y, pos, pos2
  Protected sx.f, sy.f
  Protected x1, y1
  Protected a, r, g, b
  Protected a1, r1, g1, b1
  Protected a2, r2, g2, b2

  For y = startY To stopY
    ; Pré-calc pour la ligne (évite une multiplication dans la boucle x)
    Protected y_offset = y * lg
    sy = (y - posY_start) * ratioY

    For x = 0 To lg - 1

      pos = (y_offset + x) << 2

      *dst  = *param\cible + pos
      *src1 = *param\addr[0] + pos

      getargb(*src1\l, a1, r1, g1, b1)

      ; Option 0 : inversion source
      If *param\option[0] : r1 = 255 - r1 : g1 = 255 - g1 : b1 = 255 - b1 : EndIf
      
      ; Test si pixel dans la zone
      If x >= posX_start And x < posX_end And y >= posY_start And y < posY_end

        sx = (x - posX_start) * ratioX
        x1 = Int(sx)
        y1 = Int(sy)

        pos2 = (y1 * lg_mix + x1) << 2
        
        *src2 = *param\addr[1] + pos2

        getargb(*src2\l, a2, r2, g2, b2)

        ; Option 1 : inversion du mix
        If *param\option[1] : r2 = 255 - r2 : g2 = 255 - g2 : b2 = 255 - b2 : EndIf
EndMacro


Macro Blend_Stop()
        *dst\l = (a1 << 24) | (r << 16) | (g << 8) | b
      Else
        *dst\l = (a1 << 24) | (r1 << 16 ) | (g1 << 8) | b1
      EndIf

    Next
  Next

EndMacro



Macro Filtre2_end()
  If *param\mask And *param\option[var] : *param\mask_type = *param\option[var] - 1 : MultiThread_MT(@_mask()) : EndIf
  If *tempo : FreeMemory(*tempo) : EndIf
EndMacro


;**************

Procedure Blend_additive_MT(*param.parametre)
  Blend_strat()
  min(r , (r1 + r2) , 255)
  min(g , (g1 + g2) , 255)
  min(b , (b1 + b2) , 255)
  Blend_Stop()
EndProcedure

Procedure Blend_additive(*param.parametre)
  Blend_entete_mix("additive" , #Blend_Additive)
  MultiThread_MT(@Blend_additive_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_additive_inverted_MT(*param.parametre)
  Blend_strat()
  Min(r , (r2 + (255 - r1)), 255)
  Min(g , (g2 + (255 - g1)), 255)
  Min(b , (b2 + (255 - b1)), 255)
  Blend_Stop()
EndProcedure

Procedure Blend_additive_inverted(*param.parametre)
  Blend_entete_mix("additive_inverted" , #Blend_Additive)
  MultiThread_MT(@Blend_additive_inverted_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_alphablend_MT(*param.parametre)
  Protected alpha = *param\option[6]
  clamp(alpha , 0 , 255)
  Protected inv_alpha = 255 - alpha
  Blend_strat()
  r = (r1 * alpha + r2 * inv_alpha + 127) / 255
  g = (g1 * alpha + g2 * inv_alpha + 127) / 255
  b = (b1 * alpha + b2 * inv_alpha + 127) / 255
  Blend_Stop()
EndProcedure

Procedure Blend_alphablend(*param.parametre)
  Blend_entete_mix2("alphablend","alpa" , #Blend_Additive)
  MultiThread_MT(@Blend_alphablend_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_RMSColor_MT(*param.parametre)
  ;Filtre2_QuadraticBlend
  ;Filtre2_SquaredAverage
  Blend_strat()
  r = (r1*r1*77 + r2*r2*77) >> 8
  g = (g1*g1*150 + g2*g2*150) >> 8
  b = (b1*b1*29 + b2*b2*29) >> 8
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_RMSColor(*param.parametre)
  Blend_entete_mix("Filtre2_RMSColor")
  MultiThread_MT(@Blend_RMSColor_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_And_MT(*param.parametre)
  Blend_strat()
  r = r1 & r2
  g = g1 & g2
  b = b1 & b2
  Blend_Stop()
EndProcedure

Procedure Blend_And(*param.parametre)
  Blend_entete_mix("Filtre2_And")
  MultiThread_MT(@Blend_And_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_Average_MT(*param.parametre)
  Blend_strat()
  r = (r1 + r2) >> 1
  g = (g1 + g2) >> 1
  b = (b1 + b2) >> 1
  Blend_Stop()
EndProcedure

Procedure Blend_Average(*param.parametre)
  Blend_entete_mix("Average" ,#Blend_Additive)
  MultiThread_MT(@Blend_Average_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_LightBlend_MT(*param.parametre)
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

Procedure Blend_LightBlend(*param.parametre)
  Blend_entete_mix("LightBlend" , #Blend_Additive)
  MultiThread_MT(@Blend_LightBlend_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_IntensityBoost_MT(*param.parametre)
  ;Filtre2_PowerBlend
  ;Filtre2_Amplify
  Blend_strat()
  r = r2 + ((r1 * r1 * r2) >> 16)
  g = g2 + ((g1 * g1 * g2) >> 16)
  b = b2 + ((b1 * b1 * b2) >> 16)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_IntensityBoost(*param.parametre)
  Blend_entete_mix("IntensityBoost" , #Blend_Additive)
  MultiThread_MT(@Blend_IntensityBoost_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_BrushUp_MT(*param.parametre)
  Blend_strat()
  Protected l1 = (r1 * 1225 + g1 * 2405 + b1 * 466) >> 12
  Protected l2 = (r2 * 1225 + g2 * 2405 + b2 * 466) >> 12
  r = (r1 * l2 + r2 * l1) >> 9
  g = (g1 * l2 + g2 * l1) >> 9
  b = (b1 * l2 + b2 * l1) >> 9
  ;Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_BrushUp(*param.parametre)
  Blend_entete_mix("BrushUp" , #Blend_Additive)
  MultiThread_MT(@Blend_BrushUp_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_Burn_MT(*param.parametre)
  Blend_strat()
  r = 256 - ((256 - r2) << 8) / (r1 + 1)
  g = 256 - ((256 - g2) << 8) / (g1 + 1)
  b = 256 - ((256 - b2) << 8) / (b1 + 1)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Burn(*param.parametre)
  Blend_entete_mix("Burn" , #Blend_Subtractive)
  MultiThread_MT(@Blend_Burn_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_SubtractiveDodge_MT(*param.parametre)
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

Procedure Blend_SubtractiveDodge(*param.parametre)
  Blend_entete_mix("SubtractiveDodge" , #Blend_Subtractive)
  MultiThread_MT(@Blend_SubtractiveDodge_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_ColorBurn_MT(*param.parametre)
  Blend_strat()
  r = 0 : g = 0 : b = 0
  If r1 > 0 : r = 255 - (((255 - r2) << 8) / r1) : EndIf
  If g1 > 0 : g = 255 - (((255 - g2) << 8) / g1) : EndIf
  If b1 > 0 : b = 255 - (((255 - b2) << 8) / b1) : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_ColorBurn(*param.parametre)
  ; Partie en-tête + appel multi-thread
  Blend_entete_mix("ColorBurn" , #Blend_Subtractive)
  MultiThread_MT(@Blend_ColorBurn_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_ColorDodge_MT(*param.parametre)
  Blend_strat()
  r = 0 : g = 0 : b = 0
  If r1 < 255 : Min(r, ((r2 << 8) / (255 - r1)), 255) : EndIf
  If g1 < 255 : Min(g, ((g2 << 8) / (255 - g1)), 255) : EndIf
  If b1 < 255 : Min(b, ((b2 << 8) / (255 - b1)), 255) : EndIf
  Blend_Stop()
EndProcedure

Procedure Blend_ColorDodge(*param.parametre)
  Blend_entete_mix("ColorDodge" , #Blend_Subtractive)
  MultiThread_MT(@Blend_ColorDodge_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_Contrast_MT(*param.parametre)
  Blend_strat()
  r = 127 + ((r2 - 127) * r1) / 127
  g = 127 + ((g2 - 127) * g1) / 127
  b = 127 + ((b2 - 127) * b1) / 127
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Contrast(*param.parametre)
  Blend_entete_mix("Contrast" , #Blend_Contrast)
  MultiThread_MT(@Blend_Contrast_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_Cosine_MT(*param.parametre)
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

Procedure Blend_Cosine(*param.parametre)
  Blend_entete_mix("Cosine" , #Blend_Contrast)
  MultiThread_MT(@Blend_Cosine_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_CrossFading_MT(*param.parametre)
  Protected fading = *param\option[6]
  Blend_strat()
  r = (r1 * fading + r2 * (255 - fading)) >> 8
  g = (g1 * fading + g2 * (255 - fading)) >> 8
  b = (b1 * fading + b2 * (255 - fading)) >> 8
  Blend_Stop()
EndProcedure

Procedure Blend_CrossFading(*param.parametre)
  Blend_entete_mix2("CrossFading","fading" , #Blend_Contrast)
  MultiThread_MT(@Blend_CrossFading_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_InverseMultiply_MT(*param.parametre)
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

Procedure Blend_InverseMultiply(*param.parametre)
  Blend_entete_mix("InverseMultiply" , #Blend_Multiply)
  MultiThread_MT(@Blend_InverseMultiply_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_Darken_MT(*param.parametre)
  Blend_strat()
  r = r2
  g = g2
  b = b2
  If r1 < r2 : r = r1 : EndIf
  If g1 < g2 : g = g1 : EndIf
  If b1 < b2 : b = b1 : EndIf
  Blend_Stop()
EndProcedure

Procedure Blend_Darken(*param.parametre)
  Blend_entete_mix("Darken" , #Blend_Multiply)
  MultiThread_MT(@Blend_Darken_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_SubtractiveBlend_MT(*param.parametre)
  Blend_strat()
  r = r2 - (255 - ((r1 * r2) >> 8))
  g = g2 - (255 - ((g1 * g2) >> 8))
  b = b2 - (255 - ((b1 * b2) >> 8))
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_SubtractiveBlend(*param.parametre)
  Blend_entete_mix("SubtractiveBlend" , #Blend_Subtractive)
  MultiThread_MT(@Blend_SubtractiveBlend_MT())
  Filtre2_end() 
EndProcedure
;**************
Procedure Blend_Difference_MT(*param.parametre)
  Blend_strat()
  r = Abs(r1 - r2)
  g = Abs(g1 - g2)
  b = Abs(b1 - b2)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Difference(*param.parametre)
  Blend_entete_mix("Difference" , #Blend_Multiply)
  MultiThread_MT(@Blend_Difference_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_Div_MT(*param.parametre)
  Protected m = *param\option[6]
  Blend_strat()
  r = r1 * m / (r2 + 1)
  g = g1 * m / (g2 + 1)
  b = b1 * m / (b2 + 1)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Div(*param.parametre)
  Blend_entete_mix2("Div","mul" , #Blend_Multiply)
  MultiThread_MT(@Blend_Div_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_SoftAdd_MT(*param.parametre)
  ;Filtre2_ScreenBlend
  ;Filtre2_LightenBlend
  Blend_strat()
  r = (r1 + r2) - ((r1 * r2) >> 7)
  g = (g1 + g2) - ((g1 * g2) >> 7)
  b = (b1 + b2) - ((b1 * b2) >> 7)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_SoftAdd(*param.parametre)
  Blend_entete_mix("SoftAdd" , #Blend_Additive)
  MultiThread_MT(@Blend_SoftAdd_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_SoftLightBoost_MT(*param.parametre)
  Blend_strat()
  r = r2 + r1 * (r1 / 127.5 - 1)
  g = g2 + g1 * (g1 / 127.5 - 1)
  b = b2 + b1 * (b1 / 127.5 - 1)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_SoftLightBoost(*param.parametre)
  Blend_entete_mix("Filtre2_SoftLightBoost")
  MultiThread_MT(@Blend_SoftLightBoost_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_Exponentiale_MT(*param.parametre)
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

Procedure Blend_Exponentiale(*param.parametre)
  Blend_entete_mix("Exponentiale" , #Blend_Multiply)
  MultiThread_MT(@Blend_Exponentiale_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_Fade_MT(*param.parametre)
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

Procedure Blend_Fade(*param.parametre)
  Blend_entete_mix("Filtre2_Fade")
  MultiThread_MT(@Blend_Fade_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_Fence_MT(*param.parametre)
  Blend_strat()
  r = (r2 * (r1 + r2)) >> 9 
  g = (g2 * (g1 + g2)) >> 9
  b = (b2 * (b1 + b2)) >> 9
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Fence(*param.parametre)
  Blend_entete_mix("Filtre2_Fence")
  MultiThread_MT(@Blend_Fence_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_Freeze_MT(*param.parametre)
  Blend_strat()
  r = 255 - ((255 - r1) * (255 - r1)) / (r2 + 1)
  g = 255 - ((255 - g1) * (255 - g1)) / (g2 + 1)
  b = 255 - ((255 - b1) * (255 - b1)) / (b2 + 1)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Freeze(*param.parametre)
  Blend_entete_mix("Filtre2_Freeze")
  MultiThread_MT(@Blend_Freeze_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_Glow_MT(*param.parametre)
  Blend_strat()
  r = (r2 * r2) / ((255 - r1) + 1)
  g = (g2 * g2) / ((255 - g1) + 1)
  b = (b2 * b2) / ((255 - b1) + 1)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Glow(*param.parametre)
  Blend_entete_mix("Filtre2_Glow")
  MultiThread_MT(@Blend_Glow_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_HardContrast_MT(*param.parametre)
  Blend_strat()
  If r2 > 127 : r = r2 + r1 - 127 : Else : r = r2 - r1 + 127 : EndIf
  If g2 > 127 : g = g2 + g1 - 127 : Else : g = g2 - g1 + 127 : EndIf
  If b2 > 127 : b = b2 + b1 - 127 : Else : b = b2 - b1 + 127 : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_HardContrast(*param.parametre)
  Blend_entete_mix("HardContrast" , #Blend_Contrast)
  MultiThread_MT(@Blend_HardContrast_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_Hardlight_MT(*param.parametre)
  Blend_strat()
  If r2 < 128 : r = (r1 * r2) >> 7 : Else : r = 255 - ((255 - r1) * (255 - r2) >> 7) : EndIf
  If g2 < 128 : g = (g1 * g2) >> 7 : Else : g = 255 - ((255 - g1) * (255 - g2) >> 7) : EndIf
  If b2 < 128 : b = (b1 * b2) >> 7 : Else : b = 255 - ((255 - b1) * (255 - b2) >> 7) : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Hardlight(*param.parametre)
  Blend_entete_mix("Filtre2_Hardlight")
  MultiThread_MT(@Blend_Hardlight_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_TanBlend_MT(*param.parametre)
  Blend_strat()
  r = r2 + Tan(r1 * 0.706125 - 90) * 128  
  g = g2 + Tan(g1 * 0.706125 - 90) * 128
  b = b2 + Tan(b1 * 0.706125 - 90) * 128
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_TanBlend(*param.parametre)
  Blend_entete_mix("Filtre2_TanBlend")
  MultiThread_MT(@Blend_TanBlend_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_HardlTangent_MT(*param.parametre)
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

Procedure Blend_HardlTangent(*param.parametre)
  Blend_entete_mix("Filtre2_HardlTangent")
  MultiThread_MT(@Blend_HardlTangent_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_Heat_MT(*param.parametre)
  Blend_strat()
  r = 255 - ((255 - r2) * (255 - r2)) / (r1 + 1)
  g = 255 - ((255 - g2) * (255 - g2)) / (g1 + 1)
  b = 255 - ((255 - b2) * (255 - b2)) / (b1 + 1)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Heat(*param.parametre)
  Blend_entete_mix("Filtre2_Heat")
  MultiThread_MT(@Blend_Heat_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_InHale_MT(*param.parametre)
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

Procedure Blend_InHale(*param.parametre)
  Blend_entete_mix("Filtre2_InHale")
  MultiThread_MT(@Blend_InHale_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_Intensify_MT(*param.parametre)
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

Procedure Blend_Intensify(*param.parametre)
  Blend_entete_mix("Filtre2_Intensify")
  MultiThread_MT(@Blend_Intensify_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_CosBlend_MT(*param.parametre)
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

Procedure Blend_CosBlend(*param.parametre)
  Blend_entete_mix("CosBlend" , #Blend_Contrast)
  MultiThread_MT(@Blend_CosBlend_MT())
  Filtre2_end()
EndProcedure

;**************
;-- a modifier
Procedure Blend_Interpolation_MT(*param.parametre)
  Protected Dim tab(256) , j
  For j = 0 To 255 : tab(j) = 64 - Cos(j * 3.14159265 / 255) * 64 : Next
  Protected fading = *param\option[0]
  Blend_strat() 
  r = (tab(r1) * fading + tab(r2) * (255 - fading)) >> 8
  g = (tab(g1) * fading + tab(g2) * (255 - fading)) >> 8
  b = (tab(b1) * fading + tab(b2) * (255 - fading)) >> 8
  Clamp_RGB(r, g, b)
  Blend_Stop()
  FreeArray(tab())
EndProcedure

Procedure Blend_Interpolation(*param.parametre)
  Blend_entete_mix("Filtre2_Interpolation")
  MultiThread_MT(@Blend_Interpolation_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_InvBurn_MT(*param.parametre)
  Blend_strat()
  r = 0 : g = 0 : b = 0
  If r1 > 0 : r = 255 - (255 - r2) / r1 : EndIf
  If g1 > 0 : g = 255 - (255 - g2) / g1 : EndIf
  If b1 > 0 : b = 255 - (255 - b2) / b1 : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_InvBurn(*param.parametre)
  Blend_entete_mix("InvBurn" , #Blend_Subtractive)
  MultiThread_MT(@Blend_InvBurn_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_InvColorBurn_MT(*param.parametre)
  Blend_strat()
  r = 0 : g = 0 : b = 0
  If r1 > 0 : r = 255 - (((255 - r2) << 8) / r1) : EndIf
  If g1 > 0 : g = 255 - (((255 - g2) << 8) / g1) : EndIf
  If b1 > 0 : b = 255 - (((255 - b2) << 8) / b1) : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_InvColorBurn(*param.parametre)
  Blend_entete_mix("InvColorBurn" , #Blend_Subtractive)
  MultiThread_MT(@Blend_InvColorBurn_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_InvColorDodge_MT(*param.parametre)
  Blend_strat()
  r = 255 : g = 255 : b = 255
  If r1 < 255 : r = (r2 << 8) / (255 - r1) : EndIf
  If g1 < 255 : g = (g2 << 8) / (255 - g1) : EndIf
  If b1 < 255 : b = (b2 << 8) / (255 - b1) : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_InvColorDodge(*param.parametre)
  Blend_entete_mix("InvColorDodge" , #Blend_Subtractive)
  MultiThread_MT(@Blend_InvColorDodge_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_InvDodge_MT(*param.parametre)
  Blend_strat()
  r = 255 : g = 255 : b = 255
  If r1 < 255 : r = r2 / (255 - r1) : EndIf
  If g1 < 255 : g = g2 / (255 - g1) : EndIf
  If b1 < 255 : b = b2 / (255 - b1) : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_InvDodge(*param.parametre)
  Blend_entete_mix("InvDodge" , #Blend_Subtractive)
  MultiThread_MT(@Blend_InvDodge_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_Lighten_MT(*param.parametre)
  Blend_strat()
  r = r2 : g = g2 : b = b2
  If r1 > r2 : r = r1 : EndIf
  If g1 > g2 : g = g1 : EndIf
  If b1 > b2 : b = b1 : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Lighten(*param.parametre)
  Blend_entete_mix("Lighten" ,#Blend_Additive)
  MultiThread_MT(@Blend_Lighten_MT())
  Filtre2_end()
EndProcedure                                    

;**************
Procedure Blend_LinearBurn_MT(*param.parametre)
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

Procedure Blend_LinearBurn(*param.parametre)
  Blend_entete_mix("LinearBurn" , #Blend_Subtractive)
  MultiThread_MT(@Blend_LinearBurn_MT())
  Filtre2_end()
EndProcedure      
;**************
Procedure Blend_LinearLight_MT(*param.parametre)
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

Procedure Blend_LinearLight(*param.parametre)
  Blend_entete_mix("LinearLight" , #Blend_Additive)
  MultiThread_MT(@Blend_LinearLight_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_Logarithmic_MT(*param.parametre)
  Blend_strat()
  r = 255 * (Log(r1 + 1) + Log(r2 + 1)) / (2 * Log(256))
  g = 255 * (Log(g1 + 1) + Log(g2 + 1)) / (2 * Log(256))
  b = 255 * (Log(b1 + 1) + Log(b2 + 1)) / (2 * Log(256))
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Logarithmic(*param.parametre)
  Blend_entete_mix("Filtre2_Logarithmic")
  MultiThread_MT(@Blend_Logarithmic_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_Mean_MT(*param.parametre)
  Blend_strat()
  r = (r1 + r2) >> 1
  g = (g1 + g2) >> 1
  b = (b1 + b2) >> 1
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Mean(*param.parametre)
  Blend_entete_mix("Filtre2_Mean")
  MultiThread_MT(@Blend_Mean_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_ColorVivify_MT(*param.parametre)
  Blend_strat()
  r = r2 + r1 - (g1 + b1) >> 1
  g = g2 + g1 - (r1 + b1) >> 1
  b = b2 + b1 - (g1 + r1) >> 1
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_ColorVivify(*param.parametre)
  Blend_entete_mix("Filtre2_ColorVivify")
  MultiThread_MT(@Blend_ColorVivify_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_Multiply_MT(*param.parametre)
  Blend_strat()
  r = (r1 * r2) >> 8
  g = (g1 * g2) >> 8
  b = (b1 * b2) >> 8
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Multiply(*param.parametre)
  Blend_entete_mix("Multiply" , #Blend_Multiply)
  MultiThread_MT(@Blend_Multiply_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_Negation_MT(*param.parametre)
  Blend_strat()
  r = 255 - Abs(255 - r1 - r2)
  g = 255 - Abs(255 - g1 - g2)
  b = 255 - Abs(255 - b1 - b2)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Negation(*param.parametre)
  Blend_entete_mix("Negation" , #Blend_Multiply)
  MultiThread_MT(@Blend_Negation_MT())
  Filtre2_end()
EndProcedure                  

;**************
Procedure Blend_PinLight_MT(*param.parametre)
  Blend_strat()
  If r1 < 128 : Min(r , r2, (2 * r1)) : Else : Max(r , r2, (2 * (r1 - 128))) : EndIf
  If g1 < 128 : Min(g , g2, (2 * g1)) : Else : Max(g , g2, (2 * (g1 - 128))) : EndIf
  If b1 < 128 : Min(b , b2, (2 * b1)) : Else : Max(b , b2, (2 * (b1 - 128))) : EndIf
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_PinLight(*param.parametre)
  Blend_entete_mix("Filtre2_PinLight")
  MultiThread_MT(@Blend_PinLight_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_Or_MT(*param.parametre)
  Blend_strat()
  r = r1 | r2
  g = g1 | g2
  b = b1 | b2
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Or(*param.parametre)
  Blend_entete_mix("Filtre2_Or")
  MultiThread_MT(@Blend_Or_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_Overlay_MT(*param.parametre)
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

Procedure Blend_Overlay(*param.parametre)
  Blend_entete_mix("Filtre2_Overlay")
  MultiThread_MT(@Blend_Overlay_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_Pegtop_soft_light_MT(*param.parametre)
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

Procedure Blend_Pegtop_soft_light(*param.parametre)
  Blend_entete_mix("Filtre2_Pegtop_soft_light")
  MultiThread_MT(@Blend_Pegtop_soft_light_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_quadritic_MT(*param.parametre)
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

Procedure Blend_quadritic(*param.parametre)
  Blend_entete_mix("Filtre2_quadritic")
  MultiThread_MT(@Blend_quadritic_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_Screen_MT(*param.parametre)
  Blend_strat()
  r = 255 - ((255 - r1) * (255 - r2) >> 8)
  g = 255 - ((255 - g1) * (255 - g2) >> 8)
  b = 255 - ((255 - b1) * (255 - b2) >> 8)
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Screen(*param.parametre)
  Blend_entete_mix("Screen" , #Blend_Additive)
  MultiThread_MT(@Blend_Screen_MT())
  Filtre2_end()
EndProcedure          
;**************
Procedure Blend_SoftColorBurn_MT(*param.parametre)
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

Procedure Blend_SoftColorBurn(*param.parametre)
  Blend_entete_mix("SoftColorBurn" , #Blend_Subtractive)
  MultiThread_MT(@Blend_SoftColorBurn_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_SoftColorDodge_MT(*param.parametre)
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

Procedure Blend_SoftColorDodge(*param.parametre)
  Blend_entete_mix("SoftColorDodge" , #Blend_Subtractive)
  MultiThread_MT(@Blend_SoftColorDodge_MT())
  Filtre2_end()
EndProcedure             

;**************
Procedure Blend_SoftLight_MT(*param.parametre)
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

Procedure Blend_SoftLight(*param.parametre)
  Blend_entete_mix("Filtre2_SoftLight")
  MultiThread_MT(@Blend_SoftLight_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Blend_SoftOverlay_MT(*param.parametre)
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

Procedure Blend_SoftOverlay(*param.parametre)
  Blend_entete_mix("Filtre2_SoftOverlay")
  MultiThread_MT(@Blend_SoftOverlay_MT())
  Filtre2_end()
EndProcedure                 

;**************
Procedure Blend_Stamp_MT(*param.parametre)
  Blend_strat()
  r = (r1 + r2 * 2) - 256
  g = (g1 + g2 * 2) - 256
  b = (b1 + b2 * 2) - 256
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Stamp(*param.parametre)
  Blend_entete_mix("Filtre2_Stamp")
  MultiThread_MT(@Blend_Stamp_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Blend_Subtractive_MT(*param.parametre)
  Blend_strat()
  r = (r1 + r2) - 256
  g = (g1 + g2) - 256
  b = (b1 + b2) - 256
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Subtractive(*param.parametre)
  Blend_entete_mix("Subtractive" , #Blend_Subtractive)
  MultiThread_MT(@Blend_Subtractive_MT())
  Filtre2_end()
EndProcedure                  

;**************
Procedure Blend_Xor_MT(*param.parametre)
  Blend_strat()
  r = r1 ! r2
  g = g1 ! g2
  b = b1 ! b2
  Clamp_RGB(r, g, b)
  Blend_Stop()
EndProcedure

Procedure Blend_Xor(*param.parametre)
  Blend_entete_mix("Filtre2_Xor")
  MultiThread_MT(@Blend_Xor_MT())
  Filtre2_end()
EndProcedure


; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 1118
; FirstLine = 1257
; Folding = ----------------------
; Markers = 1116
; EnableAsm
; EnableThread
; EnableXP