Procedure convolution5x5_select(opt)
Select opt
    Case 0 : Restore K5x5_GAUSSIAN_SOFT
    Case 1 : Restore K5x5_SHARPEN_HEAVY
    Case 2 : Restore K5x5_LOG
    Case 3 : Restore K5x5_MOTION_BLUR
    Case 4 : Restore K5x5_EMBOSS_HEAVY
    Case 5 : Restore K5x5_MEAN_BLUR
    Case 6 : Restore K5x5_SHARPEN_LIGHT
    Case 7 : Restore K5x5_SOBEL_H
    Case 8 : Restore K5x5_SOBEL_V
    Case 9 : Restore K5x5_HIPASS
    Case 10 : Restore K5x5_UNSHARP_MASK
    Case 11 : Restore K5x5_NEON
    Case 12 : Restore K5x5_RADIAL_APPROX
  EndSelect
EndProcedure

Procedure convolution5x5_set_Diviseur(opt.f)
  If opt = 0 : opt = 0.01 : EndIf
  FilterCtx\option[0] = opt
EndProcedure

Procedure convolution5x5_set_bias(opt.f)
  FilterCtx\option[1] = opt
EndProcedure

Procedure convolution5x5_set_matrix(opt1.i , opt2.f)
  clamp(opt1 , 0 , 24)
  FilterCtx\convol5[opt1] = opt2
EndProcedure

Procedure convolution5x5_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *src = \addr[0], *dst = \addr[1]
    Protected lg = \image_lg[0], ht = \image_ht[0]
    Protected x, y, i, r, g, b , ky , kx

    macro_calul_tread(ht)
    ; On augmente la marge de sécurité à 2 pixels pour le 5x5
    If thread_start < 2 : thread_start = 2 : EndIf
    If thread_stop > (ht-3) : thread_stop = ht - 3 : EndIf

    For y = thread_start To thread_stop
      For x = 2 To lg - 3
        r = 0 : g = 0 : b = 0
        
        ; On parcourt la matrice 5x5
        ; i indexe le coefficient (0 à 24)
        i = 0
        For ky = -2 To 2
          ; Calcul de l'adresse de la ligne concernée
          Protected *row.Pixel32 = *src + ((y + ky) * lg + (x - 2)) * 4
          
          For kx = 0 To 4
            ; Accès direct aux composantes (en supposant le format ARGB)
            ; Utilisation de masques pour la vitesse si getrgb est trop lent
            r + ((*row\l >> 16) & $FF) * \convol5[i]
            g + ((*row\l >> 8) & $FF) * \convol5[i]
            b + (*row\l & $FF) * \convol5[i]
            
            *row + 4 ; Pixel suivant sur la ligne
            i + 1
          Next
        Next

        r = (r / \option[0]) + \option[1]
        g = (g / \option[0]) + \option[1]
        b = (b / \option[0]) + \option[1]
        
        Clamp_RGB(r, g, b)
        
        Protected *dstPixel.Pixel32 = *dst + (y * lg + x) * 4
        *dstPixel\l = (Int(r) << 16) | (Int(g) << 8) | Int(b)
      Next
    Next
  EndWith
EndProcedure

Procedure convolution5x5Ex(*FilterCtx.FilterParams)
  Restore convolution5x5_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@convolution5x5_MT())
  mask_update(*FilterCtx, last_data)
EndProcedure


Procedure convolution5x5(source, cible, mask, opt = -1)
  Protected i, nom.s
  Set_Source(source) : Set_Cible(cible) : Set_Mask(mask)
  
  With FilterCtx
    If opt > -1
      convolution5x5_select(opt)
      Read.s nom
      For i = 0 To 24 ; 5x5 = 25 coefficients
        Read.f \convol5[i]
      Next
      Read.f \option[0] ; Diviseur
      Read.f \option[1] ; Bias
    EndIf
    ; Appel de la version 5x5
    convolution5x5Ex(FilterCtx)
  EndWith
EndProcedure



DataSection
  
  convolution5x5_Data:
  Data.s "Convolution 5x5"
  Data.s ""
  Data.i #FilterType_Convolution
  Data.i 0
  Data.s "Diviseur"
  Data.i 1, 255, 9
  Data.s "Bias"
  Data.i 0, 255, 0
  Data.s "XXX"
  
  K5x5_GAUSSIAN_SOFT:
  Data.s "Gaussian Blur 5x5"
  Data.f 1,  4,  7,  4, 1
  Data.f 4, 16, 26, 16, 4
  Data.f 7, 26, 41, 26, 7
  Data.f 4, 16, 26, 16, 4
  Data.f 1,  4,  7,  4, 1
  Data.f 273 ; Somme des coefficients (Diviseur)
  Data.f 0   ; Bias

  K5x5_SHARPEN_HEAVY:
  Data.s "Sharpen 5x5"
  Data.f -1, -1, -1, -1, -1
  Data.f -1,  2,  2,  2, -1
  Data.f -1,  2,  8,  2, -1
  Data.f -1,  2,  2,  2, -1
  Data.f -1, -1, -1, -1, -1
  Data.f 8   ; Somme
  Data.f 0
  
K5x5_LOG:
  Data.s "Laplacian of Gaussian"
  Data.f  0,  0, -1,  0,  0
  Data.f  0, -1, -2, -1,  0
  Data.f -1, -2, 16, -2, -1
  Data.f  0, -1, -2, -1,  0
  Data.f  0,  0, -1,  0,  0
  Data.f 1, 0

  ; --- Flou de mouvement (Motion Blur) plus long
  K5x5_MOTION_BLUR:
  Data.s "Motion Blur 5x5"
  Data.f 1, 0, 0, 0, 0
  Data.f 0, 1, 0, 0, 0
  Data.f 0, 0, 1, 0, 0
  Data.f 0, 0, 0, 1, 0
  Data.f 0, 0, 0, 0, 1
  Data.f 5, 0

  ; --- Effet de relief accentué (Emboss 5x5)
  K5x5_EMBOSS_HEAVY:
  Data.s "Emboss Heavy"
  Data.f -2, -1, -1,  0,  0
  Data.f -1, -2, -1,  0,  0
  Data.f -1, -1,  1,  1,  1
  Data.f  0,  0,  1,  2,  1
  Data.f  0,  0,  1,  1,  2
  Data.f 1, 128
  
K5x5_MEAN_BLUR:
  Data.s "Mean Blur 5x5"
  Data.f 1, 1, 1, 1, 1
  Data.f 1, 1, 1, 1, 1
  Data.f 1, 1, 1, 1, 1
  Data.f 1, 1, 1, 1, 1
  Data.f 1, 1, 1, 1, 1
  Data.f 25, 0

  ; --- Sharpen Light : Accueille les détails sans créer trop de bruit
  K5x5_SHARPEN_LIGHT:
  Data.s "Sharpen Light 5x5"
  Data.f  0,  0,  0,  0,  0
  Data.f  0, -1, -1, -1,  0
  Data.f  0, -1,  9, -1,  0
  Data.f  0, -1, -1, -1,  0
  Data.f  0,  0,  0,  0,  0
  Data.f 1, 0

  ; --- Détection de bords (Sobel 5x5 Horizontal) : Très puissant pour l'analyse
  K5x5_SOBEL_H:
  Data.s "Sobel Horizontal 5x5"
  Data.f  1,  2,  0, -2, -1
  Data.f  4,  8,  0, -8, -4
  Data.f  6, 12,  0,-12, -6
  Data.f  4,  8,  0, -8, -4
  Data.f  1,  2,  0, -2, -1
  Data.f 1, 0

  ; --- Détection de bords (Sobel 5x5 Vertical)
  K5x5_SOBEL_V:
  Data.s "Sobel Vertical 5x5"
  Data.f  1,  4,  6,  4,  1
  Data.f  2,  8, 12,  8,  2
  Data.f  0,  0,  0,  0,  0
  Data.f -2, -8,-12, -8, -2
  Data.f -1, -4, -6, -4, -1
  Data.f 1, 0

  ; --- Filtre Passe-Haut (High Pass) : Isole les textures fines
  K5x5_HIPASS:
  Data.s "High Pass 5x5"
  Data.f -1, -1, -1, -1, -1
  Data.f -1, -1, -1, -1, -1
  Data.f -1, -1, 24, -1, -1
  Data.f -1, -1, -1, -1, -1
  Data.f -1, -1, -1, -1, -1
  Data.f 1, 128

  ; --- Effet "Unsharp Mask" (Accentuation)
  K5x5_UNSHARP_MASK:
  Data.s "Unsharp Mask 5x5"
  Data.f -1, -4, -6, -4, -1
  Data.f -4,-16,-24,-16, -4
  Data.f -6,-24,476,-24, -6
  Data.f -4,-16,-24,-16, -4
  Data.f -1, -4, -6, -4, -1
  Data.f 256, 0

  ; --- Effet Sketch / Contour Néon (Laplacien fort)
  K5x5_NEON:
  Data.s "Neon Edges 5x5"
  Data.f -1, -1, -1, -1, -1
  Data.f -1,  1,  1,  1, -1
  Data.f -1,  1,  8,  1, -1
  Data.f -1,  1,  1,  1, -1
  Data.f -1, -1, -1, -1, -1
  Data.f 1, 0

  ; --- Flou Radial Approximatif
  K5x5_RADIAL_APPROX:
  Data.s "Radial Blur 5x5"
  Data.f 1, 0, 1, 0, 1
  Data.f 0, 2, 2, 2, 0
  Data.f 1, 2, 4, 2, 1
  Data.f 0, 2, 2, 2, 0
  Data.f 1, 0, 1, 0, 1
  Data.f 32, 0
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 18
; Folding = --
; EnableXP
; DPIAware