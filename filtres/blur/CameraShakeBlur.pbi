Structure ShakePath
  x.l
  y.l
EndStructure

Procedure CameraShakeBlur_GeneratePath(*param.parametre, Array path.ShakePath(1))
  ; Génère une trajectoire de tremblement aléatoire
  Protected samples = *param\option[0]  ; Nombre de points de la trajectoire
  Protected intensity = *param\option[1] ; Intensité du tremblement (rayon max)
  Protected pattern = *param\option[2]   ; Type de pattern (0=aléatoire, 1=sinusoïdal, 2=circulaire)
  Protected i
  Protected angle.f, radius.f, t.f
  
  Dim path(samples - 1)
  
  Select pattern
    Case 0  ; Trajectoire aléatoire (Brownian motion)
      Protected px.f = 0, py.f = 0
      For i = 0 To samples - 1
        px + (Random(200) - 100) / 100.0 * intensity * 0.3
        py + (Random(200) - 100) / 100.0 * intensity * 0.3
        ; Limiter l'amplitude
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
  
  ProcedureReturn samples
EndProcedure

Procedure CameraShakeBlur_MT(*param.parametre)
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected i, j, k, x, y, nx, ny
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected samples = *param\option[0]
  Protected a.l, r.l, g.l, b.l
  Protected sumA.l, sumR.l, sumG.l, sumB.l
  Protected count
  
  macro_calul_tread(ht)
  
  ; Récupération de la trajectoire pré-calculée
  Dim path.ShakePath(samples - 1)
  CopyMemory(*param\addr[3], @path(), samples * SizeOf(ShakePath))
  
  ; Traitement de chaque pixel
  For j = thread_start To thread_stop - 1
    For i = 0 To lg - 1
      sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
      count = 0
      
      ; Accumulation le long de la trajectoire
      For k = 0 To samples - 1
        nx = i + path(k)\x
        ny = j + path(k)\y
        
        ; Vérification des limites
        If nx >= 0 And nx < lg And ny >= 0 And ny < ht
          *srcPixel = *param\addr[0] + ((ny * lg + nx) << 2)
          getargb(*srcPixel\l, a, r, g, b)
          sumA + a
          sumR + r
          sumG + g
          sumB + b
          count + 1
        EndIf
      Next
      
      ; Moyenne pondérée
      If count > 0
        a = sumA / count
        r = sumR / count
        g = sumG / count
        b = sumB / count
      Else
        *srcPixel = *param\addr[0] + ((j * lg + i) << 2)
        getargb(*srcPixel\l, a, r, g, b)
      EndIf
      
      ; Écriture du résultat
      *dstPixel = *param\addr[1] + ((j * lg + i) << 2)
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
    Next
  Next
  
  FreeArray(path())
EndProcedure

Procedure CameraShakeBlur(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Directional
    *param\name = "Camera Shake Blur"
    *param\remarque = "Simule un flou de bougé d'appareil photo"
    *param\info[0] = "Samples"        ; Nombre de points (qualité)
    *param\info[1] = "Intensité"      ; Amplitude du tremblement
    *param\info[2] = "Pattern"        ; Type de trajectoire
    *param\info[3] = "Atténuation"    ; Atténuation vers les bords
    *param\info[4] = "Seed"           ; Graine aléatoire
    
    *param\info_data(0, 0) = 5  : *param\info_data(0, 1) = 50  : *param\info_data(0, 2) = 15
    *param\info_data(1, 0) = 1  : *param\info_data(1, 1) = 50  : *param\info_data(1, 2) = 10
    *param\info_data(2, 0) = 0  : *param\info_data(2, 1) = 2   : *param\info_data(2, 2) = 0
    *param\info_data(3, 0) = 0  : *param\info_data(3, 1) = 100 : *param\info_data(3, 2) = 50
    *param\info_data(4, 0) = 0  : *param\info_data(4, 1) = 999 : *param\info_data(4, 2) = 0
    ProcedureReturn
  EndIf
  
  ; Validation des paramètres
  clamp(*param\option[0], 5, 50)    ; Samples
  clamp(*param\option[1], 1, 50)    ; Intensité
  clamp(*param\option[2], 0, 2)     ; Pattern
  clamp(*param\option[3], 0, 100)   ; Atténuation
  clamp(*param\option[4], 0, 999)   ; Seed
  
  ; Initialisation du générateur aléatoire
  If *param\option[4] > 0
    RandomSeed(*param\option[4])
  Else
    RandomSeed(ElapsedMilliseconds())
  EndIf
  
  ; Génération de la trajectoire
  Protected var = *param\option[0] - 1
  Dim path.ShakePath(var)
  Protected samples = CameraShakeBlur_GeneratePath(*param.parametre, path())
  
  ; Allocation mémoire pour stocker la trajectoire (accessible aux threads)
  *param\addr[3] = AllocateMemory(samples * SizeOf(ShakePath))
  If *param\addr[3] = 0
    FreeArray(path())
    ProcedureReturn
  EndIf
  CopyMemory(@path(), *param\addr[3], samples * SizeOf(ShakePath))
  
  ; Préparation des buffers
  Filter_BufferPrepare(*param.parametre)
  
  ; Application du filtre multi-thread
  MultiThread_MT(@CameraShakeBlur_MT(), 2)
  
  ; Finalisation
  macro_Filter_BufferFinalize(4)
  
  ; Libération mémoire
  FreeMemory(*param\addr[3])
  FreeArray(path())
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 147
; FirstLine = 100
; Folding = -
; EnableXP
; DPIAware