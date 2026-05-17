; ==============================================================================
; FILTRE METAL BROSSÉ - AVEC SOURCE
; ==============================================================================

Procedure MetalEffect_MT(*p.FilterParams)
  With *p
    Protected x.i, y.i, i.i
    Protected *source.Long = \addr[0]
    Protected *cible.Long  = \addr[1]
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]

    ; --- Paramètres ---
    Protected ForceBrossage.i = \option[0] ; Étirement horizontal
    Protected Rugosite.i      = \option[1] ; Contraste du grain
    Protected Brillance.i     = \option[2] ; Luminosité des hautes lumières
    
    ; --- Multithreading ---
    Protected startY.i = ((\thread_pos * ht) / \thread_max)
    Protected stopY.i  = (((\thread_pos + 1) * ht) / \thread_max - 1)
    If stopY > (ht - 1) : stopY = (ht - 1) : EndIf

    Protected r.f, g.f, b.f, accumulation.f, pixel.l , ca
    Protected offset_dst.i, offset_src.i
    
    ; Rayon de l'étirement
    Protected radius.i = ForceBrossage
    If radius < 1 : radius = 1 : EndIf

    For y = startY To stopY
      offset_dst = (y * lg * 4)

      For x = 0 To (lg - 1)
        accumulation = 0
        
        ; --- Étape 1 : Balayage horizontal (Brossage) ---
        ; On utilise la luminance de la source pour créer les fibres
        For i = -radius To radius
          Protected nx = x + i
          ; Clamp horizontal
          If nx < 0 : nx = 0 : ElseIf nx >= lg : nx = lg - 1 : EndIf
          
          offset_src = (y * lg + nx) * 4
          pixel = PeekL(*source + offset_src)
          
          ; Extraction luminance simplifiée (R+G+B / 3)
          ca = (((pixel >> 16) & $FF) + ((pixel >> 8) & $FF) + (pixel & $FF)) / 3.0
          accumulation + ca
        Next i
        
        ; Moyenne du brossage
        Protected luminance.f = accumulation / (radius * 2 + 1)
        
        ; --- Étape 2 : Application du look "Métal" ---
        ; On booste le contraste et on ajoute la brillance
        r = luminance + (Rugosite * 2) 
        r = (r - 128) * (1.0 + Brillance / 100.0) + 128 + (Brillance * 0.5)
        
        ; Coloration légèrement bleutée/froide pour l'acier
        g = r : b = r + 5 
        
        ; --- Étape 3 : Finalisation ---
        If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
        
        PokeL(*cible + offset_dst, $FF000000 | (Int(r) << 16) | (Int(g) << 8) | Int(b))

        offset_dst + 4
      Next x
    Next y
  EndWith
EndProcedure

Procedure MetalEffectEx(*FilterCtx.FilterParams)
  Restore MetalEffect_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@MetalEffect_MT())
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure MetalEffect(source, cible, mask, brossage=10, rugosite=20, brillance=40)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = brossage
    \option[1] = rugosite
    \option[2] = brillance
  EndWith
  MetalEffectEx(FilterCtx)
EndProcedure

DataSection
  MetalEffect_Data:
  Data.s "Effet Métal (marche pas)"
  Data.s "Transforme l'image source en plaque de métal brossé"
  Data.i #FilterType_Artistic, #Artistic_Other
  Data.s "Longueur Brossage" : Data.i 1, 100, 15
  Data.s "Rugosité (Grain)" : Data.i 0, 100, 20
  Data.s "Brillance (Chrome)" : Data.i 0, 200, 50
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 80
; FirstLine = 50
; Folding = -
; EnableXP
; DPIAware