Structure ShakePath
  x.l
  y.l
EndStructure

; --- Procédure utilitaire de génération (reste interne) ---
Procedure CameraShakeBlur_GeneratePath(*FilterCtx.FilterParams, Array path.ShakePath(1))
  With *FilterCtx
    Protected samples = \option[0]  ; Nombre de points
    Protected intensity = \option[1] ; Intensité
    Protected pattern = \option[2]   ; Type de pattern
    Protected i
    Protected angle.f, radius.f, t.f
    
    Dim path(samples - 1)
    
    Select pattern
      Case 0  ; Trajectoire aléatoire (Brownian motion)
        Protected px.f = 0, py.f = 0
        For i = 0 To samples - 1
          px + (Random(200) - 100) / 100.0 * intensity * 0.3
          py + (Random(200) - 100) / 100.0 * intensity * 0.3
          radius = Sqr(px * px + py * py)
          If radius > intensity
            px = px * intensity / radius
            py = py * intensity / radius
          EndIf
          path(i)\x = Int(px)
          path(i)\y = Int(py)
        Next
        
      Case 1  ; Trajectoire sinusoïdale (oscillation)
        For i = 0 To samples - 1
          t = i / (samples - 1.0) * 2 * #PI
          path(i)\x = Int(Cos(t * 3) * intensity)
          path(i)\y = Int(Sin(t * 2) * intensity * 0.7)
        Next
        
      Case 2  ; Trajectoire circulaire avec variation
        For i = 0 To samples - 1
          t = i / (samples - 1.0) * 2 * #PI
          radius = intensity * (0.5 + 0.5 * Sin(t * 5))
          path(i)\x = Int(Cos(t) * radius)
          path(i)\y = Int(Sin(t) * radius)
        Next
    EndSelect
  EndWith
EndProcedure

; --- Procédure de calcul MT ---
Procedure CameraShakeBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected i, j, k, x, y, nx, ny
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected samples = \option[0]
    Protected a.l, r.l, g.l, b.l
    Protected sumA.l, sumR.l, sumG.l, sumB.l
    Protected count
    
    macro_calul_tread(ht)
    
    Dim path.ShakePath(samples - 1)
    CopyMemory(\addr[3], @path(), samples * SizeOf(ShakePath))
    
    For j = thread_start To thread_stop - 1
      For i = 0 To lg - 1
        sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
        count = 0
        
        For k = 0 To samples - 1
          nx = i + path(k)\x
          ny = j + path(k)\y
          
          If nx >= 0 And nx < lg And ny >= 0 And ny < ht
            *srcPixel = \addr[0] + ((ny * lg + nx) << 2)
            Protected pix.l = *srcPixel\l
            a = (pix >> 24) & $FF
            r = (pix >> 16) & $FF
            g = (pix >> 8) & $FF
            b = pix & $FF
            sumA + a : sumR + r : sumG + g : sumB + b
            count + 1
          EndIf
        Next
        
        If count > 0
          a = sumA / count : r = sumR / count : g = sumG / count : b = sumB / count
        Else
          *srcPixel = \addr[0] + ((j * lg + i) << 2)
          pix.l = *srcPixel\l
          a = (pix >> 24) & $FF : r = (pix >> 16) & $FF : g = (pix >> 8) & $FF : b = pix & $FF
        EndIf
        
        *dstPixel = \addr[1] + ((j * lg + i) << 2)
        *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
    FreeArray(path())
  EndWith
EndProcedure

; --- Procédure Ex ---
Procedure CameraShakeBlurEx(*FilterCtx.FilterParams)
  Restore CameraShakeBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    ; Initialisation du RandomSeed (logique spécifique conservée)
    If \option[4] > 0
      RandomSeed(\option[4])
    Else
      RandomSeed(ElapsedMilliseconds())
    EndIf
    
    ; Génération de la trajectoire
    Protected samplesCount = \option[0]
    Dim path.ShakePath(samplesCount - 1)
    CameraShakeBlur_GeneratePath(*FilterCtx, path())
    
    ; Stockage temporaire pour les threads
    \addr[3] = AllocateMemory(samplesCount * SizeOf(ShakePath))
    If \option[3] <> 0
      CopyMemory(@path(), \addr[3], samplesCount * SizeOf(ShakePath))
    EndIf
    
    Create_MultiThread_MT(@CameraShakeBlur_MT())
    
    mask_update(*FilterCtx, last_data)
    
    If \addr[3] : FreeMemory(\addr[3]) : \addr[3] = 0 : EndIf
    FreeArray(path())
  EndWith
EndProcedure

; --- Interface simplifiée ---
Procedure CameraShakeBlur(source, cible, mask, samples, intensite, pattern, attenuation, seed)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = samples
    \option[1] = intensite
    \option[2] = pattern
    \option[3] = attenuation
    \option[4] = seed
  EndWith
  CameraShakeBlurEx(FilterCtx.FilterParams)
EndProcedure

; --- DataSection ---
DataSection
  CameraShakeBlur_data:
  Data.s "CameraShakeBlur"
  Data.s "Simule un flou de bougé d'appareil photo"
  Data.i #FilterType_Blur
  Data.i #Blur_Directional
  
  Data.s "Échantillons" ; Samples
  Data.i 5, 50, 15
  Data.s "Intensité" 
  Data.i 1, 50, 10
  Data.s "Pattern (0:Alé, 1:Sin, 2:Circ)"
  Data.i 0, 2, 0
  Data.s "Atténuation"
  Data.i 0, 100, 50
  Data.s "Graine (Seed)"
  Data.i 0, 999, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 172
; FirstLine = 121
; Folding = -
; EnableXP
; DPIAware