Procedure TextureSynthesis_MT(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected windowSize = *param\option[0]
  Protected maxError.f = *param\option[1] / 100.0
  Protected searchStep = *param\option[2]
  Protected seedType = *param\option[3]
  
  Protected pos, i, j, x, y
  Protected wx, wy, sx, sy
  Protected *scr.Pixel32
  Protected *dst.Pixel32
  Protected a, r, g, b
  Protected ar, rr, gr, br
  Protected bestX, bestY
  Protected minDist.f, currentDist.f
  Protected halfWin = windowSize >> 1
  Protected seed, validPixels
  
  ; Gestion du seed aléatoire
  If seedType = 0
    seed = ElapsedMilliseconds()
  Else
    seed = seedType * 12345
  EndIf
  
  ; Initialisation : copier un pixel seed au centre
  Protected seedX = lg >> 1
  Protected seedY = ht >> 1
  
  ; Initialiser toute l'image comme "non remplie"
  For y = 0 To ht - 1
    For x = 0 To lg - 1
      pos = (y * lg + x) << 2
      *dst = *param\addr[1] + pos
      *dst\l = $FF000000  ; Marque "non rempli"
    Next
  Next
  
  ; Placer le pixel seed au centre
  pos = (seedY * lg + seedX) << 2
  *scr = *param\addr[0] + pos
  *dst = *param\addr[1] + pos
  *dst\l = *scr\l
  
  ; Structure pour stocker les candidats
  Structure Candidate
    x.l
    y.l
    dist.f
  EndStructure
  
  Protected NewList unfilled.Candidate()
  Protected NewList candidates.Candidate()
  
  ; Ajouter les voisins du seed dans la liste unfilled
  For wy = -1 To 1
    For wx = -1 To 1
      If wx = 0 And wy = 0 : Continue : EndIf
      Protected nx = seedX + wx
      Protected ny = seedY + wy
      If nx >= 0 And nx < lg And ny >= 0 And ny < ht
        AddElement(unfilled())
        unfilled()\x = nx
        unfilled()\y = ny
        unfilled()\dist = 0
      EndIf
    Next
  Next
  
  ; Boucle principale : remplir pixel par pixel
  Protected iterations = 0
  Protected maxIterations = lg * ht * 2
  Protected startY, endY, startX, endX
  
  startY = halfWin
  endY = ht - halfWin - 1
  startX = halfWin
  endX = lg - halfWin - 1
  max(startY, 0, ht - 1)
  max(endY, 0, ht - 1)
  max(startX, 0, lg - 1)
  max(endX, 0, lg - 1)
  
  While ListSize(unfilled()) > 0 And iterations < maxIterations
    iterations + 1
    
    ; Prendre le premier pixel non rempli
    FirstElement(unfilled())
    Protected targetX = unfilled()\x
    Protected targetY = unfilled()\y
    DeleteElement(unfilled())
    
    ; Vérifier si déjà rempli (peut arriver avec les doublons)
    pos = (targetY * lg + targetX) << 2
    *dst = *param\addr[1] + pos
    If (*dst\l & $00FFFFFF) <> 0
      Continue
    EndIf
    
    ; Recherche des meilleurs candidats dans l'image source
    ClearList(candidates())
    minDist = 999999999.0
    
    sy = startY
    While sy <= endY
      sx = startX
      While sx <= endX
        ; Calculer la distance entre le voisinage cible et le voisinage source
        currentDist = 0.0
        validPixels = 0
        
        For wy = -halfWin To halfWin
          For wx = -halfWin To halfWin
            Protected tx = targetX + wx
            Protected ty = targetY + wy
            
            If tx >= 0 And tx < lg And ty >= 0 And ty < ht
              Protected tpos = (ty * lg + tx) << 2
              Protected *tdst.Pixel32 = *param\addr[1] + tpos
              
              ; Seulement comparer les pixels déjà remplis dans la cible
              If (*tdst\l & $00FFFFFF) <> 0
                getargb(*tdst\l, a, r, g, b)
                
                ; Pixel correspondant dans la source
                Protected srcX = sx + wx
                Protected srcY = sy + wy
                If srcX >= 0 And srcX < lg And srcY >= 0 And srcY < ht
                  Protected srcPos = (srcY * lg + srcX) << 2
                  *scr = *param\addr[0] + srcPos
                  getargb(*scr\l, ar, rr, gr, br)
                  
                  ; Distance euclidienne au carré (plus rapide)
                  Protected dr = r - rr
                  Protected dg = g - gr
                  Protected db = b - br
                  currentDist + (dr*dr + dg*dg + db*db)
                  validPixels + 1
                EndIf
              EndIf
            EndIf
          Next
        Next
        
        If validPixels > 0
          currentDist / validPixels
          
          ; Garder les candidats proches du minimum
          If currentDist < minDist * 1.5
            If currentDist < minDist
              minDist = currentDist
            EndIf
            
            AddElement(candidates())
            candidates()\x = sx
            candidates()\y = sy
            candidates()\dist = currentDist
          EndIf
        EndIf
        
        sx + searchStep
      Wend
      
      sy + searchStep
    Wend
    
    ; Sélection aléatoire parmi les meilleurs candidats
    If ListSize(candidates()) > 0
      ; Filtrer pour garder seulement ceux proches du minimum
      Protected threshold.f = minDist * (1.0 + maxError)
      ForEach candidates()
        If candidates()\dist > threshold
          DeleteElement(candidates())
        EndIf
      Next
      
      ; Choisir aléatoirement parmi les meilleurs
      If ListSize(candidates()) > 0
        Protected listSize = ListSize(candidates())
        Protected chosenIndex = Random(listSize - 1, seed)
        seed = (seed * 1103515245 + 12345) & $7FFFFFFF
        
        Protected idx = 0
        ForEach candidates()
          If idx = chosenIndex
            bestX = candidates()\x
            bestY = candidates()\y
            Break
          EndIf
          idx + 1
        Next
        
        ; Copier le pixel choisi
        pos = (targetY * lg + targetX) << 2
        *dst = *param\addr[1] + pos
        Protected bestPos = (bestY * lg + bestX) << 2
        *scr = *param\addr[0] + bestPos
        *dst\l = *scr\l
        
        ; Ajouter les voisins non remplis à la liste
        For wy = -1 To 1
          For wx = -1 To 1
            If wx = 0 And wy = 0 : Continue : EndIf
            nx = targetX + wx
            ny = targetY + wy
            If nx >= 0 And nx < lg And ny >= 0 And ny < ht
              Protected npos = (ny * lg + nx) << 2
              Protected *nptr.Pixel32 = *param\addr[1] + npos
              
              ; Si non rempli, ajouter à la liste
              If (*nptr\l & $00FFFFFF) = 0
                ; Vérifier s'il n'est pas déjà dans la liste (éviter doublons)
                Protected alreadyListed = #False
                ForEach unfilled()
                  If unfilled()\x = nx And unfilled()\y = ny
                    alreadyListed = #True
                    Break
                  EndIf
                Next
                
                If Not alreadyListed
                  AddElement(unfilled())
                  unfilled()\x = nx
                  unfilled()\y = ny
                EndIf
              EndIf
            EndIf
          Next
        Next
      Else
        ; Si aucun candidat valide, prendre un pixel aléatoire
        sx = Random(lg - 1, seed)
        sy = Random(ht - 1, seed)
        seed = (seed * 1103515245 + 12345) & $7FFFFFFF
        max(sx, 0, lg - 1)
        max(sy, 0, ht - 1)
        
        pos = (targetY * lg + targetX) << 2
        *dst = *param\addr[1] + pos
        bestPos = (sy * lg + sx) << 2
        *scr = *param\addr[0] + bestPos
        *dst\l = *scr\l
        
        ; Ajouter voisins
        For wy = -1 To 1
          For wx = -1 To 1
            If wx = 0 And wy = 0 : Continue : EndIf
            nx = targetX + wx
            ny = targetY + wy
            If nx >= 0 And nx < lg And ny >= 0 And ny < ht
              npos = (ny * lg + nx) << 2
              *nptr.Pixel32 = *param\addr[1] + npos
              If (*nptr\l & $00FFFFFF) = 0
                alreadyListed = #False
                ForEach unfilled()
                  If unfilled()\x = nx And unfilled()\y = ny
                    alreadyListed = #True
                    Break
                  EndIf
                Next
                If Not alreadyListed
                  AddElement(unfilled())
                  unfilled()\x = nx
                  unfilled()\y = ny
                EndIf
              EndIf
            EndIf
          Next
        Next
      EndIf
    EndIf
  Wend
  
  ; Remplir les pixels restants avec des valeurs aléatoires
  For y = 0 To ht - 1
    For x = 0 To lg - 1
      pos = (y * lg + x) << 2
      *dst = *param\addr[1] + pos
      If (*dst\l & $00FFFFFF) = 0
        sx = Random(lg - 1, seed)
        sy = Random(ht - 1, seed)
        seed = (seed * 1103515245 + 12345) & $7FFFFFFF
        max(sx, 0, lg - 1)
        max(sy, 0, ht - 1)
        Protected fillPos = (sy * lg + sx) << 2
        *scr = *param\addr[0] + fillPos
        *dst\l = *scr\l
      EndIf
    Next
  Next
EndProcedure

Procedure Texture_Synthesis(*param.parametre)
  If *param\info_active
    *param\typ = #FilterType_Texture
    *param\subtype = 0;#Stylize_Texture
    *param\name = "TextureSynthesis"
    *param\remarque = "Synthèse de texture (Efros-Leung) pixel par pixel"
    *param\info[0] = "Taille fenêtre"
    *param\info[1] = "Tolérance %"
    *param\info[2] = "Pas recherche"
    *param\info[3] = "Seed"
    *param\info[4] = "Masque binaire"
    
    *param\info_data(0,0) = 3   : *param\info_data(0,1) = 21  : *param\info_data(0,2) = 7
    *param\info_data(1,0) = 0   : *param\info_data(1,1) = 50  : *param\info_data(1,2) = 10
    *param\info_data(2,0) = 1   : *param\info_data(2,1) = 10  : *param\info_data(2,2) = 3
    *param\info_data(3,0) = 0   : *param\info_data(3,1) = 100 : *param\info_data(3,2) = 0
    *param\info_data(4,0) = 0   : *param\info_data(4,1) = 2   : *param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  
  Filter_BufferPrepare(*param.parametre)
  
  TextureSynthesis_MT(*param)
  
  macro_Filter_BufferFinalize(4)
EndProcedure
; IDE Options = PureBasic 6.30 (Windows - x64)
; CursorPosition = 293
; FirstLine = 249
; Folding = -
; EnableXP
; DPIAware