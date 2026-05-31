
Macro Filtre_entete_mix(nom) 
  If param\info_active
    param\typ = #Filter_Type_mix
    param\name = nom
    param\remarque = ""         
    param\info[0] = "invert image"   
    param\info[1] = "neg image 1"
    param\info[2] = "neg image 2"
    param\info[3] = "scaleX image 2"
    param\info[4] = "scaleX image 2"
    param\info[5] = "PosX image 2"
    param\info[6] = "Posy image 2"
    param\info[7] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 1  : param\info_data(0,2) = 0 
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1  : param\info_data(1,2) = 0 
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1  : param\info_data(2,2) = 0 
    param\info_data(3,0) = 0 : param\info_data(3,1) = 100  : param\info_data(3,2) = 100 
    param\info_data(4,0) = 0 : param\info_data(4,1) = 100  : param\info_data(4,2) = 100
    param\info_data(5,0) = 0 : param\info_data(5,1) = 200  : param\info_data(5,2) = 100
    param\info_data(6,0) = 0 : param\info_data(6,1) = 200  : param\info_data(6,2) = 100
    param\info_data(7,0) = 0 : param\info_data(7,1) = 2  : param\info_data(7,2) = 0
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
  
  *param\addr[1] = *param\source2
  If *param\option[0]
    Swap *param\addr[0] , *param\addr[1]
  EndIf
  Protected var = 7 ; = "Masque binaire"
EndMacro

Macro Filtre_entete_mix2(nom,op1) 
  If param\info_active
    param\typ = #Filter_Type_mix
    param\name = nom
    param\remarque = ""   
    param\info[0] = "invert image" 
    param\info[1] = "neg image 1"
    param\info[2] = "neg image 2"
    param\info[3] = "scaleX image 2"
    param\info[4] = "scaleX image 2"
    param\info[5] = "PosX image 2"
    param\info[6] = "Posy image 2"
    param\info[7] = op1   
    param\info[8] = "Masque binaire" 
    param\info_data(0,0) = 0 : param\info_data(0,1) = 1  : param\info_data(0,2) = 0 
    param\info_data(1,0) = 0 : param\info_data(1,1) = 1  : param\info_data(1,2) = 0 
    param\info_data(2,0) = 0 : param\info_data(2,1) = 1  : param\info_data(2,2) = 0 
    param\info_data(3,0) = 0 : param\info_data(3,1) = 100  : param\info_data(3,2) = 100 
    param\info_data(4,0) = 0 : param\info_data(4,1) = 100  : param\info_data(4,2) = 100
    param\info_data(5,0) = 0 : param\info_data(5,1) = 200  : param\info_data(5,2) = 100
    param\info_data(6,0) = 0 : param\info_data(6,1) = 200  : param\info_data(6,2) = 100
    param\info_data(7,0) = 0 : param\info_data(7,1) = 255  : param\info_data(7,2) = 128
    param\info_data(8,0) = 0 : param\info_data(8,1) = 2  : param\info_data(8,2) = 0
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\source2 = 0 Or  *param\cible = 0 : ProcedureReturn : EndIf
  
  Protected *tempo
  If *param\source = *param\cible
    *tempo = AllocateMemory(*param\lg * *param\ht * 4)
    If Not *tempo : ProcedureReturn : EndIf
    CopyMemory(*param\source , *tempo , *param\lg * *param\ht * 4)
    *param\addr[0] = *tempo
  Else
    *param\addr[0] = *param\source
  EndIf
  
  *param\addr[1] = *param\source2
  If *param\option[0]
    Swap *param\addr[0] , *param\addr[1]
  EndIf
  Protected var = 8 ; = "Masque binaire"
EndMacro


Macro Filtre2_start()
  Protected *src1.Pixel32 = *param\source
  Protected *src2.Pixel32 = *param\source2
  Protected *dst.Pixel32 = *param\cible
  
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected scale_x = *param\option[3]; max 100% = lg
  Protected scale_y = *param\option[4] ; max 100% = ht
  Protected posX_start = ((*param\option[5]-100) * lg) / 100
  Protected posY_start = ((*param\option[6]-100) * ht) / 100
  Protected lg2 = (lg * scale_x) / 100
  Protected ht2 = (ht * scale_y) / 100
  Protected posX_end
  Protected posY_end
  Min(posX_end , lg, (posX_start + lg2))
  Min(posY_end , ht, (posY_start + ht2))
  
  Protected cx = lg2 / 2
  Protected cy = ht2 / 2
  
  Protected dx
  Protected dy
  
  Protected x , y , x1 , y1 , pos , pos2
  Protected a , r , g , b 
  Protected a1 , r1 , g1 , b1
  Protected a2 , r2 , g2 , b2
  
  Protected start = (*param\thread_pos * ht) / *param\thread_max
  Protected stop  = (( *param\thread_pos + 1) * ht) / *param\thread_max - 1
  If stop >= ht - 1 : stop = ht - 1 : EndIf
  
  For y = start To stop
    For x = 0 To lg -1
      pos = (y * lg + x) << 2
      *dst = *param\cible + pos
      *src1 = *param\addr[0] + pos
      getargb(*src1\l , a1 , r1 , g1 , b1)
      If *param\option[1] : r1 = 255 - r1 : g1 = 255 - g1 : b1 = 255 - b1 : EndIf
      
      If x >= posX_start And y >= posY_start And x < posX_end And y < posY_end

          x1 = ((x - posX_start) * lg) / lg2
          y1 = ((y - posY_start) * ht) / ht2
          pos2 = (y1 * lg + x1) << 2
          *src2 = *param\addr[1] + pos2
          getargb(*src2\l , a2 , r2 , g2 , b2)
          If *param\option[2] : r2 = 255 - r2 : g2 = 255 - g2 : b2 = 255 - b2 : EndIf
EndMacro
  
 
Macro Filtre2_stop()
      *dst\l = (a1 <<24) | (r << 16 ) | (g << 8) | b
    Else
      *dst\l = (a1 <<24) | (r1 << 16 ) | (g1 << 8) | b1
    EndIf
    Next
  Next
EndMacro

Macro Filtre2_end()
  If *param\mask And *param\option[var] : *param\mask_type = *param\option[var] - 1 : MultiThread_MT(@_mask()) : EndIf
  If *tempo : FreeMemory(*tempo) : EndIf
EndMacro

;**************

Procedure Filtre2_additive_MT(*param.parametre)
  Filtre2_start()
  min(r , (r1 + r2) , 255)
  min(g , (g1 + g2) , 255)
  min(b , (b1 + b2) , 255)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_additive(*param.parametre)
  Filtre_entete_mix("Filtre2_additive")
  MultiThread_MT(@Filtre2_additive_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_additive_inverted_MT(*param.parametre)
  Filtre2_start()
  Min(r , (r2 + (255 - r1)), 255)
  Min(g , (g2 + (255 - g1)), 255)
  Min(b , (b2 + (255 - b1)), 255)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_additive_inverted(*param.parametre)
  Filtre_entete_mix("Filtre2_additive_inverted")
  MultiThread_MT(@Filtre2_additive_inverted_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_alphablend_MT(*param.parametre)
  Protected alpha = *param\option[7]
  clamp(alpha , 0 , 255)
  Protected inv_alpha = 255 - alpha
  Filtre2_start()
  r = (r1 * alpha + r2 * inv_alpha + 127) / 255
  g = (g1 * alpha + g2 * inv_alpha + 127) / 255
  b = (b1 * alpha + b2 * inv_alpha + 127) / 255
  Filtre2_stop()
EndProcedure

Procedure Filtre2_alphablend(*param.parametre)
  Filtre_entete_mix2("Filtre2_alphablend","alpa")
  MultiThread_MT(@Filtre2_alphablend_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_RMSColor_MT(*param.parametre)
  ;Filtre2_QuadraticBlend
  ;Filtre2_SquaredAverage
  Filtre2_start()
  r = (r1*r1*77 + r2*r2*77) >> 8
  g = (g1*g1*150 + g2*g2*150) >> 8
  b = (b1*b1*29 + b2*b2*29) >> 8
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_RMSColor(*param.parametre)
  Filtre_entete_mix("Filtre2_RMSColor")
  MultiThread_MT(@Filtre2_RMSColor_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_And_MT(*param.parametre)
  Filtre2_start()
  r = r1 & r2
  g = g1 & g2
  b = b1 & b2
  Filtre2_stop()
EndProcedure

Procedure Filtre2_And(*param.parametre)
  Filtre_entete_mix("Filtre2_And")
  MultiThread_MT(@Filtre2_And_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_Average_MT(*param.parametre)
  Filtre2_start()
  r = (r1 + r2) >> 1
  g = (g1 + g2) >> 1
  b = (b1 + b2) >> 1
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Average(*param.parametre)
  Filtre_entete_mix("Filtre2_Average")
  MultiThread_MT(@Filtre2_Average_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_LightBlend_MT(*param.parametre)
  ;Filtre2_IntensityBlend
  ;Filtre2_WeightedBlend
  Filtre2_start()
  Protected v = r1 + g1 + b1
  r = ((r2 * v) + (r1 * v)) >> 11
  g = ((g2 * v) + (g1 * v)) >> 11
  b = ((b2 * v) + (b1 * v)) >> 11
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_LightBlend(*param.parametre)
  Filtre_entete_mix("Filtre2_LightBlend")
  MultiThread_MT(@Filtre2_LightBlend_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_IntensityBoost_MT(*param.parametre)
  ;Filtre2_PowerBlend
  ;Filtre2_Amplify
  Filtre2_start()
  r = r2 + ((r1 * r1 * r2) >> 16)
  g = g2 + ((g1 * g1 * g2) >> 16)
  b = b2 + ((b1 * b1 * b2) >> 16)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_IntensityBoost(*param.parametre)
  Filtre_entete_mix("Filtre2_IntensityBoost")
  MultiThread_MT(@Filtre2_IntensityBoost_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_BrushUp_MT(*param.parametre)
  Filtre2_start()
  Protected l1 = (r1 * 1225 + g1 * 2405 + b1 * 466) >> 12
  Protected l2 = (r2 * 1225 + g2 * 2405 + b2 * 466) >> 12
  r = (r1 * l2 + r2 * l1) >> 9
  g = (g1 * l2 + g2 * l1) >> 9
  b = (b1 * l2 + b2 * l1) >> 9
  ;Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_BrushUp(*param.parametre)
  Filtre_entete_mix("Filtre2_BrushUp")
  MultiThread_MT(@Filtre2_BrushUp_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_Burn_MT(*param.parametre)
  Filtre2_start()
  r = 256 - ((256 - r2) << 8) / (r1 + 1)
  g = 256 - ((256 - g2) << 8) / (g1 + 1)
  b = 256 - ((256 - b2) << 8) / (b1 + 1)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Burn(*param.parametre)
  Filtre_entete_mix("Filtre2_Burn")
  MultiThread_MT(@Filtre2_Burn_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_SubtractiveDodge_MT(*param.parametre)
  ;Filtre2_LinearDodge
  Filtre2_start()
  Max(r , 0, (r2 - 255 + r1))
  Max(g , 0, (g2 - 255 + g1))
  Max(b , 0, (b2 - 255 + b1))
  Min(r , 255, (r2 - r))
  Min(g , 255, (g2 - g))
  Min(b , 255, (b2 - b))
  Filtre2_stop()
EndProcedure

Procedure Filtre2_SubtractiveDodge(*param.parametre)
  Filtre_entete_mix("Filtre2_SubtractiveDodge")
  MultiThread_MT(@Filtre2_SubtractiveDodge_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_ColorBurn_MT(*param.parametre)
  Filtre2_start()
  r = 0 : g = 0 : b = 0
  If r1 > 0 : r = 255 - (((255 - r2) << 8) / r1) : EndIf
  If g1 > 0 : g = 255 - (((255 - g2) << 8) / g1) : EndIf
  If b1 > 0 : b = 255 - (((255 - b2) << 8) / b1) : EndIf
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_ColorBurn(*param.parametre)
  ; Partie en-tête + appel multi-thread
  Filtre_entete_mix("Filtre2_ColorBurn")
  MultiThread_MT(@Filtre2_ColorBurn_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_ColorDodge_MT(*param.parametre)
  Filtre2_start()
  r = 0 : g = 0 : b = 0
  If r1 < 255 : Min(r, ((r2 << 8) / (255 - r1)), 255) : EndIf
  If g1 < 255 : Min(g, ((g2 << 8) / (255 - g1)), 255) : EndIf
  If b1 < 255 : Min(b, ((b2 << 8) / (255 - b1)), 255) : EndIf
  Filtre2_stop()
EndProcedure

Procedure Filtre2_ColorDodge(*param.parametre)
  Filtre_entete_mix("Filtre2_ColorDodge")
  MultiThread_MT(@Filtre2_ColorDodge_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_Contrast_MT(*param.parametre)
  Filtre2_start()
  r = 127 + ((r2 - 127) * r1) / 127
  g = 127 + ((g2 - 127) * g1) / 127
  b = 127 + ((b2 - 127) * b1) / 127
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Contrast(*param.parametre)
  Filtre_entete_mix("Filtre2_Contrast")
  MultiThread_MT(@Filtre2_Contrast_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_Cosine_MT(*param.parametre)
  Protected Dim CosLUT(256) , j
  For j = 0 To 255 : CosLUT(j) = Int(Abs(Cos(j * 3.14159265 / 255)) * 255) : Next
  Filtre2_start()
  r = (CosLUT(r1) * r2) >> 8
  g = (CosLUT(g1) * g2) >> 8
  b = (CosLUT(b1) * b2) >> 8
  Clamp_RGB(r, g, b)
  Filtre2_stop()
  FreeArray(CosLUT())
EndProcedure

Procedure Filtre2_Cosine(*param.parametre)
  Filtre_entete_mix("Filtre2_Cosine")
  MultiThread_MT(@Filtre2_Cosine_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_CrossFading_MT(*param.parametre)
  Protected fading = *param\option[7]
  Filtre2_start()
  r = (r1 * fading + r2 * (255 - fading)) >> 8
  g = (g1 * fading + g2 * (255 - fading)) >> 8
  b = (b1 * fading + b2 * (255 - fading)) >> 8
  Filtre2_stop()
EndProcedure

Procedure Filtre2_CrossFading(*param.parametre)
  Filtre_entete_mix2("Filtre2_CrossFading","fading")
  MultiThread_MT(@Filtre2_CrossFading_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_InverseMultiply_MT(*param.parametre)
  Filtre2_start()
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
  Filtre2_stop()
EndProcedure

Procedure Filtre2_InverseMultiply(*param.parametre)
  Filtre_entete_mix("Filtre2_InverseMultiply")
  MultiThread_MT(@Filtre2_InverseMultiply_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_Darken_MT(*param.parametre)
  Filtre2_start()
  r = r2
  g = g2
  b = b2
  If r1 < r2 : r = r1 : EndIf
  If g1 < g2 : g = g1 : EndIf
  If b1 < b2 : b = b1 : EndIf
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Darken(*param.parametre)
  Filtre_entete_mix("Filtre2_Darken")
  MultiThread_MT(@Filtre2_Darken_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_SubtractiveBlend_MT(*param.parametre)
  Filtre2_start()
  r = r2 - (255 - ((r1 * r2) >> 8))
  g = g2 - (255 - ((g1 * g2) >> 8))
  b = b2 - (255 - ((b1 * b2) >> 8))
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_SubtractiveBlend(*param.parametre)
  Filtre_entete_mix("Filtre2_SubtractiveBlend")
  MultiThread_MT(@Filtre2_SubtractiveBlend_MT())
  Filtre2_end() 
EndProcedure
;**************
Procedure Filtre2_Difference_MT(*param.parametre)
  Filtre2_start()
  r = Abs(r1 - r2)
  g = Abs(g1 - g2)
  b = Abs(b1 - b2)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Difference(*param.parametre)
  Filtre_entete_mix("Filtre2_Difference")
  MultiThread_MT(@Filtre2_Difference_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_Div_MT(*param.parametre)
  Protected m = *param\option[7]
  Filtre2_start()
  r = r1 * m / (r2 + 1)
  g = g1 * m / (g2 + 1)
  b = b1 * m / (b2 + 1)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Div(*param.parametre)
  Filtre_entete_mix2("Filtre2_Div","mul")
  MultiThread_MT(@Filtre2_Div_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_SoftAdd_MT(*param.parametre)
  ;Filtre2_ScreenBlend
  ;Filtre2_LightenBlend
  Filtre2_start()
  r = (r1 + r2) - ((r1 * r2) >> 7)
  g = (g1 + g2) - ((g1 * g2) >> 7)
  b = (b1 + b2) - ((b1 * b2) >> 7)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_SoftAdd(*param.parametre)
  Filtre_entete_mix("Filtre2_SoftAdd")
  MultiThread_MT(@Filtre2_SoftAdd_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_SoftLightBoost_MT(*param.parametre)
  Filtre2_start()
  r = r2 + r1 * (r1 / 127.5 - 1)
  g = g2 + g1 * (g1 / 127.5 - 1)
  b = b2 + b1 * (b1 / 127.5 - 1)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_SoftLightBoost(*param.parametre)
  Filtre_entete_mix("Filtre2_SoftLightBoost")
  MultiThread_MT(@Filtre2_SoftLightBoost_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_Exponentiale_MT(*param.parametre)
  Protected Dim ExpLUT(256) , j
  For j = 0 To 255
    ExpLUT(j) = Int(Pow(255, j / 255.0) + 0.5)  ; valeur entière arrondie
    If ExpLUT(j) > 255 : ExpLUT(j) = 255 : EndIf
  Next
  Filtre2_start()
  r = (ExpLUT(r1) * r2) >> 8
  g = (ExpLUT(g1) * g2) >> 8
  b = (ExpLUT(b1) * b2) >> 8
  Clamp_RGB(r, g, b)
  Filtre2_stop()
  FreeArray(ExpLUT())
EndProcedure

Procedure Filtre2_Exponentiale(*param.parametre)
  Filtre_entete_mix("Filtre2_Exponentiale")
  MultiThread_MT(@Filtre2_Exponentiale_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_Fade_MT(*param.parametre)
  Protected Dim SumLUT(766) , j
  For j = 0 To 765 : SumLUT(j) = j : Next
  Filtre2_start()
  Protected s2 = SumLUT(r2 + g2 + b2)
  Protected s1 = SumLUT(r1 + g1 + b1)
  r = ((r2 + s2) * (r1 + s1)) >> 12
  g = ((g2 + s2) * (g1 + s1)) >> 12
  b = ((b2 + s2) * (b1 + s1)) >> 12
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Fade(*param.parametre)
  Filtre_entete_mix("Filtre2_Fade")
  MultiThread_MT(@Filtre2_Fade_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_Fence_MT(*param.parametre)
  Filtre2_start()
  r = (r2 * (r1 + r2)) >> 9 
  g = (g2 * (g1 + g2)) >> 9
  b = (b2 * (b1 + b2)) >> 9
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Fence(*param.parametre)
  Filtre_entete_mix("Filtre2_Fence")
  MultiThread_MT(@Filtre2_Fence_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_Freeze_MT(*param.parametre)
  Filtre2_start()
  r = 255 - ((255 - r1) * (255 - r1)) / (r2 + 1)
  g = 255 - ((255 - g1) * (255 - g1)) / (g2 + 1)
  b = 255 - ((255 - b1) * (255 - b1)) / (b2 + 1)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Freeze(*param.parametre)
  Filtre_entete_mix("Filtre2_Freeze")
  MultiThread_MT(@Filtre2_Freeze_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_Glow_MT(*param.parametre)
  Filtre2_start()
  r = (r2 * r2) / ((255 - r1) + 1)
  g = (g2 * g2) / ((255 - g1) + 1)
  b = (b2 * b2) / ((255 - b1) + 1)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Glow(*param.parametre)
  Filtre_entete_mix("Filtre2_Glow")
  MultiThread_MT(@Filtre2_Glow_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_HardContrast_MT(*param.parametre)
  Filtre2_start()
  If r2 > 127 : r = r2 + r1 - 127 : Else : r = r2 - r1 + 127 : EndIf
  If g2 > 127 : g = g2 + g1 - 127 : Else : g = g2 - g1 + 127 : EndIf
  If b2 > 127 : b = b2 + b1 - 127 : Else : b = b2 - b1 + 127 : EndIf
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_HardContrast(*param.parametre)
  Filtre_entete_mix("Filtre2_HardContrast")
  MultiThread_MT(@Filtre2_HardContrast_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_Hardlight_MT(*param.parametre)
  Filtre2_start()
  If r2 < 128 : r = (r1 * r2) >> 7 : Else : r = 255 - ((255 - r1) * (255 - r2) >> 7) : EndIf
  If g2 < 128 : g = (g1 * g2) >> 7 : Else : g = 255 - ((255 - g1) * (255 - g2) >> 7) : EndIf
  If b2 < 128 : b = (b1 * b2) >> 7 : Else : b = 255 - ((255 - b1) * (255 - b2) >> 7) : EndIf
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Hardlight(*param.parametre)
  Filtre_entete_mix("Filtre2_Hardlight")
  MultiThread_MT(@Filtre2_Hardlight_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_TanBlend_MT(*param.parametre)
  Filtre2_start()
  r = r2 + Tan(r1 * 0.706125 - 90) * 128  
  g = g2 + Tan(g1 * 0.706125 - 90) * 128
  b = b2 + Tan(b1 * 0.706125 - 90) * 128
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_TanBlend(*param.parametre)
  Filtre_entete_mix("Filtre2_TanBlend")
  MultiThread_MT(@Filtre2_TanBlend_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_HardlTangent_MT(*param.parametre)
  Protected Dim tab(255) , j , c
  ;For j = 0 To 255 : tab(j) = Tan(j * 180 / 256 - 90) * 128 : Next
  c = 4 ; 8 ou 16
  For j = 0 To 255 : tab(j) = TanH((j - 128) / c) * 128 : Next
  Filtre2_start()
  r = r2 + tab(r1)
  g = g2 + tab(g1)
  b = b2 + tab(b1)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
  FreeArray(tab())
EndProcedure

Procedure Filtre2_HardlTangent(*param.parametre)
  Filtre_entete_mix("Filtre2_HardlTangent")
  MultiThread_MT(@Filtre2_HardlTangent_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_Heat_MT(*param.parametre)
  Filtre2_start()
  r = 255 - ((255 - r2) * (255 - r2)) / (r1 + 1)
  g = 255 - ((255 - g2) * (255 - g2)) / (g1 + 1)
  b = 255 - ((255 - b2) * (255 - b2)) / (b1 + 1)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Heat(*param.parametre)
  Filtre_entete_mix("Filtre2_Heat")
  MultiThread_MT(@Filtre2_Heat_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_InHale_MT(*param.parametre)
  Protected Dim tab(255) , j
  For j = 0 To 255 : tab(j) = (255 - j) * ((255 - j) / 127.5 - 1) : Clamp(tab(j), 0, 255) : Next
  Filtre2_start()
  r = r2 - tab(r1)
  g = g2 - tab(g1)
  b = b2 - tab(b1)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
  FreeArray(tab())
EndProcedure

Procedure Filtre2_InHale(*param.parametre)
  Filtre_entete_mix("Filtre2_InHale")
  MultiThread_MT(@Filtre2_InHale_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_Intensify_MT(*param.parametre)
  Protected Dim tab(256) , j
  For j = 0 To 255 : tab(j) = 64 - Cos(j * 3.14 / 255) * 64 : Next
  Filtre2_start()
  r = r2 + ((r1 * r2) >> 8)
  g = g2 + ((g1 * g2) >> 8)
  b = b2 + ((b1 * b2) >> 8)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
  FreeArray(tab())
EndProcedure

Procedure Filtre2_Intensify(*param.parametre)
  Filtre_entete_mix("Filtre2_Intensify")
  MultiThread_MT(@Filtre2_Intensify_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_CosBlend_MT(*param.parametre)
  Protected Dim tab(256) , j
  For j = 0 To 255 : tab(j) = 64 - Cos(j * 3.14 / 255) * 64 : Next
  Filtre2_start()
  r = tab(r1) + tab(r2)
  g = tab(g1) + tab(g2)
  b = tab(b1) + tab(b2)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
  FreeArray(tab())
EndProcedure

Procedure Filtre2_CosBlend(*param.parametre)
  Filtre_entete_mix("Filtre2_CosBlend")
  MultiThread_MT(@Filtre2_CosBlend_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_Interpolation_MT(*param.parametre)
  Protected Dim tab(256) , j
  For j = 0 To 255 : tab(j) = 64 - Cos(j * 3.14159265 / 255) * 64 : Next
  Protected fading = *param\option[0]
  Filtre2_start() 
  r = (tab(r1) * fading + tab(r2) * (255 - fading)) >> 8
  g = (tab(g1) * fading + tab(g2) * (255 - fading)) >> 8
  b = (tab(b1) * fading + tab(b2) * (255 - fading)) >> 8
  Clamp_RGB(r, g, b)
  Filtre2_stop()
  FreeArray(tab())
EndProcedure

Procedure Filtre2_Interpolation(*param.parametre)
  Filtre_entete_mix("Filtre2_Interpolation")
  MultiThread_MT(@Filtre2_Interpolation_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_InvBurn_MT(*param.parametre)
  Filtre2_start()
  r = 0 : g = 0 : b = 0
  If r1 > 0 : r = 255 - (255 - r2) / r1 : EndIf
  If g1 > 0 : g = 255 - (255 - g2) / g1 : EndIf
  If b1 > 0 : b = 255 - (255 - b2) / b1 : EndIf
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_InvBurn(*param.parametre)
  Filtre_entete_mix("Filtre2_InvBurn")
  MultiThread_MT(@Filtre2_InvBurn_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_InvColorBurn_MT(*param.parametre)
  Filtre2_start()
  r = 0 : g = 0 : b = 0
  If r1 > 0 : r = 255 - (((255 - r2) << 8) / r1) : EndIf
  If g1 > 0 : g = 255 - (((255 - g2) << 8) / g1) : EndIf
  If b1 > 0 : b = 255 - (((255 - b2) << 8) / b1) : EndIf
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_InvColorBurn(*param.parametre)
  Filtre_entete_mix("Filtre2_InvColorBurn")
  MultiThread_MT(@Filtre2_InvColorBurn_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_InvColorDodge_MT(*param.parametre)
  Filtre2_start()
  r = 255 : g = 255 : b = 255
  If r1 < 255 : r = (r2 << 8) / (255 - r1) : EndIf
  If g1 < 255 : g = (g2 << 8) / (255 - g1) : EndIf
  If b1 < 255 : b = (b2 << 8) / (255 - b1) : EndIf
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_InvColorDodge(*param.parametre)
  Filtre_entete_mix("Filtre2_InvColorDodge")
  MultiThread_MT(@Filtre2_InvColorDodge_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_InvDodge_MT(*param.parametre)
  Filtre2_start()
  r = 255 : g = 255 : b = 255
  If r1 < 255 : r = r2 / (255 - r1) : EndIf
  If g1 < 255 : g = g2 / (255 - g1) : EndIf
  If b1 < 255 : b = b2 / (255 - b1) : EndIf
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_InvDodge(*param.parametre)
  Filtre_entete_mix("Filtre2_InvDodge")
  MultiThread_MT(@Filtre2_InvDodge_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_Lighten_MT(*param.parametre)
  Filtre2_start()
  r = r2 : g = g2 : b = b2
  If r1 > r2 : r = r1 : EndIf
  If g1 > g2 : g = g1 : EndIf
  If b1 > b2 : b = b1 : EndIf
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Lighten(*param.parametre)
  Filtre_entete_mix("Filtre2_Lighten")
  MultiThread_MT(@Filtre2_Lighten_MT())
  Filtre2_end()
EndProcedure                                    

;**************
Procedure Filtre2_LinearBurn_MT(*param.parametre)
  Filtre2_start()
  r = r1 + r2
  g = g1 + g2
  b = b1 + b2
  If r < 256 : r = 0 : Else : r = r - 255 : EndIf
  If g < 256 : g = 0 : Else : g = g - 255 : EndIf
  If b < 256 : b = 0 : Else : b = b - 255 : EndIf
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure                               

Procedure Filtre2_LinearBurn(*param.parametre)
  Filtre_entete_mix("Filtre2_LinearBurn")
  MultiThread_MT(@Filtre2_LinearBurn_MT())
  Filtre2_end()
EndProcedure      
;**************
Procedure Filtre2_LinearLight_MT(*param.parametre)
  Protected Dim comps(2)
  Protected Dim src1(2), Dim src2(2)
  Protected k
  Filtre2_start()
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
  Filtre2_stop()
  FreeArray(comps())
  FreeArray(src1())
  FreeArray(src2())
EndProcedure

Procedure Filtre2_LinearLight(*param.parametre)
  Filtre_entete_mix("Filtre2_LinearLight")
  MultiThread_MT(@Filtre2_LinearLight_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_Logarithmic_MT(*param.parametre)
  Filtre2_start()
  r = 255 * (Log(r1 + 1) + Log(r2 + 1)) / (2 * Log(256))
  g = 255 * (Log(g1 + 1) + Log(g2 + 1)) / (2 * Log(256))
  b = 255 * (Log(b1 + 1) + Log(b2 + 1)) / (2 * Log(256))
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Logarithmic(*param.parametre)
  Filtre_entete_mix("Filtre2_Logarithmic")
  MultiThread_MT(@Filtre2_Logarithmic_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_Mean_MT(*param.parametre)
  Filtre2_start()
  r = (r1 + r2) >> 1
  g = (g1 + g2) >> 1
  b = (b1 + b2) >> 1
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Mean(*param.parametre)
  Filtre_entete_mix("Filtre2_Mean")
  MultiThread_MT(@Filtre2_Mean_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_ColorVivify_MT(*param.parametre)
  Filtre2_start()
  r = r2 + r1 - (g1 + b1) >> 1
  g = g2 + g1 - (r1 + b1) >> 1
  b = b2 + b1 - (g1 + r1) >> 1
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_ColorVivify(*param.parametre)
  Filtre_entete_mix("Filtre2_ColorVivify")
  MultiThread_MT(@Filtre2_ColorVivify_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_Multiply_MT(*param.parametre)
  Filtre2_start()
  r = (r1 * r2) >> 8
  g = (g1 * g2) >> 8
  b = (b1 * b2) >> 8
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Multiply(*param.parametre)
  Filtre_entete_mix("Filtre2_Multiply")
  MultiThread_MT(@Filtre2_Multiply_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_Negation_MT(*param.parametre)
  Filtre2_start()
  r = 255 - Abs(255 - r1 - r2)
  g = 255 - Abs(255 - g1 - g2)
  b = 255 - Abs(255 - b1 - b2)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Negation(*param.parametre)
  Filtre_entete_mix("Filtre2_Negation")
  MultiThread_MT(@Filtre2_Negation_MT())
  Filtre2_end()
EndProcedure                  

;**************
Procedure Filtre2_PinLight_MT(*param.parametre)
  Filtre2_start()
  If r1 < 128 : Min(r , r2, (2 * r1)) : Else : Max(r , r2, (2 * (r1 - 128))) : EndIf
  If g1 < 128 : Min(g , g2, (2 * g1)) : Else : Max(g , g2, (2 * (g1 - 128))) : EndIf
  If b1 < 128 : Min(b , b2, (2 * b1)) : Else : Max(b , b2, (2 * (b1 - 128))) : EndIf
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_PinLight(*param.parametre)
  Filtre_entete_mix("Filtre2_PinLight")
  MultiThread_MT(@Filtre2_PinLight_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_Or_MT(*param.parametre)
  Filtre2_start()
  r = r1 | r2
  g = g1 | g2
  b = b1 | b2
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Or(*param.parametre)
  Filtre_entete_mix("Filtre2_Or")
  MultiThread_MT(@Filtre2_Or_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_Overlay_MT(*param.parametre)
  Filtre2_start()
  r = (r1 * r2) >> 7
  g = (g1 * g2) >> 7
  b = (b1 * b2) >> 7
  If r1 >= 128 : r = 255 - ((255 - r1) * (255 - r2) >> 7) : EndIf
  If g1 >= 128 : g = 255 - ((255 - g1) * (255 - g2) >> 7) : EndIf
  If b1 >= 128 : b = 255 - ((255 - b1) * (255 - b2) >> 7) : EndIf
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Overlay(*param.parametre)
  Filtre_entete_mix("Filtre2_Overlay")
  MultiThread_MT(@Filtre2_Overlay_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_Pegtop_soft_light_MT(*param.parametre)
  Filtre2_start()
  Protected c = (r1 * r2) >> 8
  r = c + r1 * (255 - ((255 - r1) * (255 - r2) >> 8) - c) >> 8
  c = (g1 * g2) >> 8
  g = c + g1 * (255 - ((255 - g1) * (255 - g2) >> 8) - c) >> 8
  c = (b1 * b2) >> 8
  b = c + b1 * (255 - ((255 - b1) * (255 - b2) >> 8) - c) >> 8
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Pegtop_soft_light(*param.parametre)
  Filtre_entete_mix("Filtre2_Pegtop_soft_light")
  MultiThread_MT(@Filtre2_Pegtop_soft_light_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_quadritic_MT(*param.parametre)
  Filtre2_start()
  r = 255
  If r2 <> 255 : r = r1 * r1 / (255 - r2) : EndIf
  g = 255
  If g2 <> 255 : g = g1 * g1 / (255 - g2) : EndIf
  b = 255
  If b2 <> 255 : b = b1 * b1 / (255 - b2) : EndIf
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_quadritic(*param.parametre)
  Filtre_entete_mix("Filtre2_quadritic")
  MultiThread_MT(@Filtre2_quadritic_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_Screen_MT(*param.parametre)
  Filtre2_start()
  r = 255 - ((255 - r1) * (255 - r2) >> 8)
  g = 255 - ((255 - g1) * (255 - g2) >> 8)
  b = 255 - ((255 - b1) * (255 - b2) >> 8)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Screen(*param.parametre)
  Filtre_entete_mix("Filtre2_Screen")
  MultiThread_MT(@Filtre2_Screen_MT())
  Filtre2_end()
EndProcedure          
;**************
Procedure Filtre2_SoftColorBurn_MT(*param.parametre)
  Filtre2_start()
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
  Filtre2_stop()
EndProcedure

Procedure Filtre2_SoftColorBurn(*param.parametre)
  Filtre_entete_mix("Filtre2_SoftColorBurn")
  MultiThread_MT(@Filtre2_SoftColorBurn_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_SoftColorDodge_MT(*param.parametre)
  Filtre2_start()
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
  Filtre2_stop()
EndProcedure

Procedure Filtre2_SoftColorDodge(*param.parametre)
  Filtre_entete_mix("Filtre2_SoftColorDodge")
  MultiThread_MT(@Filtre2_SoftColorDodge_MT())
  Filtre2_end()
EndProcedure             

;**************
Procedure Filtre2_SoftLight_MT(*param.parametre)
  Protected k
  Filtre2_start()
  Protected Dim src1(2), Dim src2(2), Dim res(2)
  src1(0)=r1 : src1(1)=g1 : src1(2)=b1
  src2(0)=r2 : src2(1)=g2 : src2(2)=b2 
  For k = 0 To 2
    Protected c = (src1(k) * src2(k)) >> 8
    res(k) = c + src1(k) * (255 - (((255 - src1(k)) * (255 - src2(k))) >> 8) - c) >> 8
  Next
  r = res(0) : g = res(1) : b = res(2)
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_SoftLight(*param.parametre)
  Filtre_entete_mix("Filtre2_SoftLight")
  MultiThread_MT(@Filtre2_SoftLight_MT())
  Filtre2_end()
EndProcedure
;**************
Procedure Filtre2_SoftOverlay_MT(*param.parametre)
  Filtre2_start()
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
  Filtre2_stop()
EndProcedure

Procedure Filtre2_SoftOverlay(*param.parametre)
  Filtre_entete_mix("Filtre2_SoftOverlay")
  MultiThread_MT(@Filtre2_SoftOverlay_MT())
  Filtre2_end()
EndProcedure                 

;**************
Procedure Filtre2_Stamp_MT(*param.parametre)
  Filtre2_start()
  r = (r1 + r2 * 2) - 256
  g = (g1 + g2 * 2) - 256
  b = (b1 + b2 * 2) - 256
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Stamp(*param.parametre)
  Filtre_entete_mix("Filtre2_Stamp")
  MultiThread_MT(@Filtre2_Stamp_MT())
  Filtre2_end()
EndProcedure

;**************
Procedure Filtre2_Subtractive_MT(*param.parametre)
  Filtre2_start()
  r = (r1 + r2) - 256
  g = (g1 + g2) - 256
  b = (b1 + b2) - 256
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Subtractive(*param.parametre)
  Filtre_entete_mix("Filtre2_Subtractive")
  MultiThread_MT(@Filtre2_Subtractive_MT())
  Filtre2_end()
EndProcedure                  

;**************
Procedure Filtre2_Xor_MT(*param.parametre)
  Filtre2_start()
  r = r1 ! r2
  g = g1 ! g2
  b = b1 ! b2
  Clamp_RGB(r, g, b)
  Filtre2_stop()
EndProcedure

Procedure Filtre2_Xor(*param.parametre)
  Filtre_entete_mix("Filtre2_Xor")
  MultiThread_MT(@Filtre2_Xor_MT())
  Filtre2_end()
EndProcedure


; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 1275
; FirstLine = 1225
; Folding = ----------------------
; Markers = 1090
; EnableAsm
; EnableThread
; EnableXP