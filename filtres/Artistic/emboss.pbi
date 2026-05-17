; =============================================================================
; FILTRE ARTISTIQUE "EMBOSS" - STRUCTURE RÉVISÉE
; =============================================================================

Procedure emboss_MT(*p.FilterParams)
  With *p
    ; --- Dimensions de l'image ---
    Protected w = \image_lg[0]
    Protected h = \image_ht[0]
    
    ; --- Coordonnées ---
    Protected x, y
    
    ; --- Composantes ARGB ---
    Protected a, r, g, b
    Protected rL, gL, bL, rR, gR, bR
    Protected rU, gU, bU, rD, gD, bD
    Protected rC, gC, bC
    
    ; --- Niveaux de gris ---
    Protected grayL.f, grayR.f
    Protected grayU.f, grayD.f
    
    ; --- Gradients ---
    Protected dx.f, dy.f
    
    ; --- Vecteur normale ---
    Protected nx.f, ny.f, nz.f
    Protected len.f
    
    ; --- Pointeurs mémoire ---
    Protected *src.Pixel32
    Protected *dst.Pixel32
    
    ; ============================================================================
    ; LECTURE DES PARAMÈTRES
    ; ============================================================================
    Protected strength.f = \option[0] * 0.01
    Protected invertY    = \option[1]
    Protected renforcer  = \option[2]
    Protected lightMode  = \option[3]
    
    Protected lightAngle.f = \option[4] * #PI / 180.0
    Protected lightElevation.f = \option[5] * #PI / 180.0
    
    Protected lx.f = Cos(lightAngle) * Cos(lightElevation)
    Protected ly.f = Sin(lightAngle) * Cos(lightElevation)
    Protected lz.f = Sin(lightElevation)
    
    If strength <= 0.0 : strength = 0.01 : EndIf
    If renforcer : strength * 4.0 : EndIf
    
    ; ============================================================================
    ; CONFIGURATION MULTITHREADING
    ; ============================================================================
    Protected startY = (\thread_pos * h) / \thread_max
    Protected endY   = ((\thread_pos + 1) * h) / \thread_max
    
    If startY < 1 : startY = 1 : EndIf
    If endY > h - 1 : endY = h - 1 : EndIf
    
    ; ============================================================================
    ; TRAITEMENT PRINCIPAL
    ; ============================================================================
    For y = startY To endY - 1
      For x = 1 To w - 2
        
        *src = \addr[0] + ((y * w + x) << 2)
        GetARGB(*src\l, a, rC, gC, bC)
        
        ; Pixel GAUCHE (x-1)
        *src = \addr[0] + ((y * w + (x - 1)) << 2)
        GetARGB(*src\l, a, rL, gL, bL)
        
        ; Pixel DROITE (x+1)
        *src = \addr[0] + ((y * w + (x + 1)) << 2)
        GetARGB(*src\l, a, rR, gR, bR)
        
        ; Pixel HAUT (y-1)
        *src = \addr[0] + (((y - 1) * w + x) << 2)
        GetARGB(*src\l, a, rU, gU, bU)
        
        ; Pixel BAS (y+1)
        *src = \addr[0] + (((y + 1) * w + x) << 2)
        GetARGB(*src\l, a, rD, gD, bD)
        
        grayL = (rL + gL + bL) * 0.333333
        grayR = (rR + gR + bR) * 0.333333
        grayU = (rU + gU + bU) * 0.333333
        grayD = (rD + gD + bD) * 0.333333
        
        dx = (grayR - grayL) * strength
        dy = (grayD - grayU) * strength
        If invertY : dy = -dy : EndIf
        
        nx = -dx
        ny = -dy
        nz = 1.0
        
        len = Sqr(nx*nx + ny*ny + nz*nz)
        If len > 0.0001
          nx / len
          ny / len
          nz / len
        EndIf
        
        Select lightMode
          Case 0  ; MODE NORMAL MAP
            r = Int((nx * 0.5 + 0.5) * 255)
            g = Int((ny * 0.5 + 0.5) * 255)
            b = Int((nz * 0.5 + 0.5) * 255)
            
          Case 1  ; MODE EMBOSS AVEC COULEUR
            Protected dot.f = nx * lx + ny * ly + nz * lz
            If dot < 0.0 : dot = 0.0 : EndIf
            r = Int(rC * (0.3 + 0.7 * dot))
            g = Int(gC * (0.3 + 0.7 * dot))
            b = Int(bC * (0.3 + 0.7 * dot))
            
          Case 2  ; MODE EMBOSS RELIEF (NOIR & BLANC)
            Protected dot2.f = nx * lx + ny * ly + nz * lz
            Protected intensity.f = 128 + dot2 * 127
            If intensity < 0 : intensity = 0 : ElseIf intensity > 255 : intensity = 255 : EndIf
            r = Int(intensity)
            g = Int(intensity)
            b = Int(intensity)
        EndSelect
        
        If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
        If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
        If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
        
        *dst = \addr[1] + ((y * w + x) << 2)
        *dst\l = (255 << 24) | (r << 16) | (g << 8) | b
        
      Next
    Next
  EndWith
EndProcedure

Procedure embossEx(*FilterCtx.FilterParams)
  Restore emboss_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  With *FilterCtx
    Create_MultiThread_MT(@emboss_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure emboss(source, cible, mask, hauteur=30, invY=0, boost=0, mode=1, angle=135, elev=45)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = hauteur
    \option[1] = invY
    \option[2] = boost
    \option[3] = mode
    \option[4] = angle
    \option[5] = elev
  EndWith
  embossEx(FilterCtx)
EndProcedure

DataSection
  emboss_Data:
  Data.s "Emboss avec Lumière"
  Data.s "Effet emboss avec contrôle directionnel de la lumière"
  Data.i #FilterType_Artistic, #Artistic_Other
  Data.s "Hauteur"           : Data.i 1, 100, 30
  Data.s "Inverser Y"        : Data.i 0, 1, 0
  Data.s "Renforcer (x4)"    : Data.i 0, 1, 0
  Data.s "Mode (0=Normal/1=Couleur/2=Relief)" : Data.i 0, 2, 1
  Data.s "Angle lumière (0-359°)" : Data.i 0, 359, 135
  Data.s "Élévation lumière (0-89°)" : Data.i 0, 89, 45
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 150
; FirstLine = 126
; Folding = -
; EnableXP
; DPIAware