Procedure InkBlur_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected i, j, k, x, y
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    Protected radius = \option[0]        ; Rayon du flou
    Protected flow = \option[1]          ; Fluidité de l'encre (0-100)
    Protected density = \option[2]       ; Densité de l'encre (0-100)
    Protected spread = \option[3]        ; Diffusion/étalement (0-100)
    
    Protected a.l, r.l, g.l, b.l
    Protected sumA.l, sumR.l, sumG.l, sumB.l
    Protected count, px, py
    Protected diameter = radius * 2 + 1
    Protected weight.f, total_weight.f
    Protected dx, dy, dist.f
    
    ; Variables pour l'effet encre
    Protected gray.l, ink_value.l
    Protected flow_factor.f, density_factor.f
    Protected edge_x.f, edge_y.f, edge_mag.f
    Protected direction.f, anisotropic_weight.f
    
    macro_calul_tread(ht)
    
    ; Traitement de chaque pixel
    For j = thread_start To thread_stop - 1
      For i = 0 To lg - 1
        
        ; === Détection de la direction du flux (gradient) ===
        edge_x = 0 : edge_y = 0
        
        For y = -1 To 1
          py = j + y
          If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf
          
          For x = -1 To 1
            px = i + x
            If px < 0 : px = 0 : ElseIf px >= lg : px = lg - 1 : EndIf
            
            *srcPixel = \addr[0] + ((py * lg + px) << 2)
            getargb(*srcPixel\l, a, r, g, b)
            gray = (r * 299 + g * 587 + b * 114) / 1000
            
            ; Gradient de Sobel
            edge_x + gray * x
            edge_y + gray * y
          Next
        Next
        
        edge_mag = Sqr(edge_x * edge_x + edge_y * edge_y)
        If edge_mag > 0.001
          direction = ATan2(edge_y, edge_x)
        Else
          direction = 0
        EndIf
        
        ; === Flou anisotropique (directionnel) ===
        sumA = 0 : sumR = 0 : sumG = 0 : sumB = 0
        total_weight = 0
        flow_factor = flow / 100.0
        
        For y = -radius To radius
          py = j + y
          If py < 0 : py = 0 : ElseIf py >= ht : py = ht - 1 : EndIf
          
          For x = -radius To radius
            px = i + x
            If px < 0 : px = 0 : ElseIf px >= lg : px = lg - 1 : EndIf
            
            dx = x
            dy = y
            dist = Sqr(dx * dx + dy * dy)
            
            ; Pondération de base (gaussienne)
            weight = Exp(-(dist * dist) / (2.0 * radius * radius / 3.0))
            
            ; Pondération anisotropique selon la direction du flux
            If flow_factor > 0 And edge_mag > 10
              Protected pixel_angle.f = ATan2(dy, dx)
              Protected angle_diff.f = Abs(pixel_angle - direction)
              
              ; Normaliser l'angle entre 0 et PI
              If angle_diff > #PI : angle_diff = 2 * #PI - angle_diff : EndIf
              
              ; Favoriser la direction perpendiculaire au gradient (flux de l'encre)
              anisotropic_weight = 1.0 + flow_factor * Cos(angle_diff)
              weight * anisotropic_weight
            EndIf
            
            *srcPixel = \addr[0] + ((py * lg + px) << 2)
            getargb(*srcPixel\l, a, r, g, b)
            
            sumA + a * weight
            sumR + r * weight
            sumG + g * weight
            sumB + b * weight
            total_weight + weight
          Next
        Next
        
        ; Moyenne pondérée
        If total_weight > 0
          a = sumA / total_weight
          r = sumR / total_weight
          g = sumG / total_weight
          b = sumB / total_weight
        Else
          *srcPixel = \addr[0] + ((j * lg + i) << 2)
          getargb(*srcPixel\l, a, r, g, b)
        EndIf
        
        ; === Effet Encre ===
        
        ; Conversion en niveaux de gris
        gray = (r * 299 + g * 587 + b * 114) / 1000
        
        ; Application de la densité (courbe non-linéaire)
        density_factor = density / 100.0
        Protected normalized.f = gray / 255.0
        
        ; Courbe de densité de l'encre (assombrit les zones moyennes)
        Protected ink_curve.f
        If normalized < 0.5
          ink_curve = normalized * normalized * 2.0
        Else
          ink_curve = 1.0 - (1.0 - normalized) * (1.0 - normalized) * 2.0
        EndIf
        
        ; Mix entre original et courbe de densité
        normalized = normalized * (1.0 - density_factor) + ink_curve * density_factor
        
        ; Application de l'étalement (dispersion)
        If spread > 0
          Protected spread_factor.f = spread / 100.0
          
          ; Pseudo-random dispersion basée sur position et magnitude du gradient
          Protected dispersion.f = Mod((i * 179 + j * 233 + Int(edge_mag)) , 100) / 100.0
          dispersion = (dispersion - 0.5) * spread_factor * 0.3
          
          ; Plus d'étalement sur les contours (où l'encre coule)
          If edge_mag > 20
            dispersion * (1.0 + edge_mag / 100.0)
          EndIf
          
          normalized + dispersion
        EndIf
        
        ; Clamping
        If normalized < 0 : normalized = 0 : EndIf
        If normalized > 1 : normalized = 1 : EndIf
        
        ink_value = normalized * 255
        
        ; Préservation des couleurs originales avec l'intensité de l'encre
        Protected ink_ratio.f = 1.0 - normalized
        
        r = r * (1.0 - ink_ratio * 0.3)
        g = g * (1.0 - ink_ratio * 0.3)
        b = b * (1.0 - ink_ratio * 0.3)
        
        ; Clamping final
        If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
        
        ; Écriture du résultat
        *dstPixel = \addr[1] + ((j * lg + i) << 2)
        *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      Next
    Next
  EndWith
EndProcedure

Procedure InkBlurEx(*FilterCtx.FilterParams)
  Restore InkBlur_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf

  Create_MultiThread_MT(@InkBlur_MT())
  
  mask_update(*FilterCtx , last_data)
EndProcedure

Procedure InkBlur(source, cible, mask, rayon, fluidite, densite, etalement)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rayon
    \option[1] = fluidite
    \option[2] = densite
    \option[3] = etalement
  EndWith
  InkBlurEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  InkBlur_data:
  Data.s "InkBlur"
  Data.s "Effet encre fluide avec flou directionnel"
  Data.i #FilterType_Blur
  Data.i #Blur_Artistic
  
  Data.s "Rayon"
  Data.i 1, 30, 5
  Data.s "Fluidité"
  Data.i 0, 100, 60
  Data.s "Densité"
  Data.i 0, 100, 50
  Data.s "Étalement"
  Data.i 0, 100, 30
  Data.s "Réservé"
  Data.i 0, 100, 0
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 186
; FirstLine = 166
; Folding = -
; EnableXP
; DPIAware