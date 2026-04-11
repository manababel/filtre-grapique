Procedure blur_box_Guillossien_create_limit(*param.parametre)
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected rx = *param\option[0]
  Protected ry = *param\option[1]
  Protected boucle = *param\option[3]
  Protected i, ii, e
  Protected dx = lg - 1
  Protected dy = ht - 1
  If rx > dx : rx = dx : EndIf
  If ry > dy : ry = dy : EndIf
  Protected nrx = rx + 1
  Protected nry = ry + 1
  Protected sizeX = (lg + 2 * nrx) * 4
  Protected sizeY = (ht + 2 * nry) * 4
  ; Allocation d’un seul bloc
  *param\addr[2] = AllocateMemory(sizeX + sizeY)
  If *param\addr[2] = 0 : ProcedureReturn 0 : EndIf
  
  *param\addr[3] = *param\addr[2]
  *param\addr[4] = *param\addr[2] + sizeX
  ; Remplissage des tables
  If boucle
    e = dx - nrx / 2 : For i = 0 To dx + 2 * nrx : PokeL(*param\addr[3] + i * 4, (i + e) % (dx + 1)) : Next
    e = dy - nry / 2 : For i = 0 To dy + 2 * nry : PokeL(*param\addr[4] + i * 4, (i + e) % (dy + 1)) : Next
  Else
    For i = 0 To dx + 2 * nrx : ii = i - 1 - nrx / 2 : If ii < 0 : ii = 0 : ElseIf ii > dx : ii = dx : EndIf : PokeL(*param\addr[3] + i * 4, ii) : Next
    For i = 0 To dy + 2 * nry : ii = i - 1 - nry / 2 : If ii < 0 : ii = 0 : ElseIf ii > dy : ii = dy : EndIf : PokeL(*param\addr[4] + i * 4, ii) : Next
  EndIf
  ProcedureReturn 1
EndProcedure



Procedure blur_box_Guillossien_MT(*param.parametre)
  ; Déclarations de pointeurs pixel source/destination
  Protected *srcPixel1.Pixel32
  Protected *srcPixel2.Pixel32
  Protected *dstPixel.Pixel32
  ; Accumulateurs pour composantes ARGB
  Protected ax1, rx1, gx1, bx1
  Protected a1.l, r1.l, b1.l, g1.l
  Protected a2.l, r2.l, b2.l, g2.l
  ; Index temporaires
  Protected j, i, p1, p2
  ; Paramètres de l’image
  Protected lx = *param\addr[3]
  Protected ly = *param\addr[4]
  Protected lg = *param\lg
  Protected ht = *param\ht
  ; Paramètres du filtre
  Protected nrx = *param\option[0] + 1
  Protected nry = *param\option[1] + 1
  Protected div = Int($800000 / (nrx * nry))  ; Pow(2,23) = $800000

  macro_calul_tread(ht)

  ; Buffers pour accumuler les sommes par colonne
  Protected Dim a.l(lg) , Dim r.l(lg) , Dim g.l(lg) , Dim b.l(lg)
  ; Initialisation des buffers
  FillMemory(@a(), lg * 4, 0) : FillMemory(@r(), lg * 4, 0) : FillMemory(@g(), lg * 4, 0) : FillMemory(@b(), lg * 4, 0)
  ; === Étape 1 : Accumule les lignes verticales pour démarrer ===
  For j = 0 To nry - 1
    p1 = PeekL(ly + (j + thread_start) << 2)
    *srcPixel1 = *param\addr[0] + ((p1 * lg) << 2)
    For i = 0 To lg - 1
      getargb(*srcPixel1\l, a1, r1, g1, b1)
      a(i) + a1 : r(i) + r1 : g(i) + g1 : b(i) + b1
      *srcPixel1 + 4
    Next
  Next
  ; === Étape 2 : Application du filtre pour chaque ligne ===
  For j = thread_start To thread_stop - 1
    ; Mise à jour du buffer colonne (soustraction d’une ancienne ligne et ajout d’une nouvelle)
    p1 = PeekL(ly + (nry + j) << 2)
    p2 = PeekL(ly + (j << 2))
    *srcPixel1 = *param\addr[0] + (p1 * lg) << 2
    *srcPixel2 = *param\addr[0] + (p2 * lg) << 2
    For i = 0 To lg - 1
      getargb(*srcPixel1\l, a1, r1, g1, b1)
      getargb(*srcPixel2\l, a2, r2, g2, b2)
      a(i) + a1 - a2
      r(i) + r1 - r2
      g(i) + g1 - g2
      b(i) + b1 - b2
      *srcPixel1 + 4
      *srcPixel2 + 4
    Next
    ; Application du filtre horizontal
    ax1 = 0 : rx1 = 0 : gx1 = 0 : bx1 = 0
    For i = 0 To nrx - 1
      p1 = PeekL(lx + (i << 2))
      ax1 + a(p1)
      rx1 + r(p1)
      gx1 + g(p1)
      bx1 + b(p1)
    Next
    ; Boucle de sortie pour chaque pixel de la ligne
    For i = 0 To lg - 1
      p1 = PeekL(lx + (nrx + i) << 2)
      p2 = PeekL(lx + (i << 2))
      ax1 + a(p1) - a(p2)
      rx1 + r(p1) - r(p2)
      gx1 + g(p1) - g(p2)
      bx1 + b(p1) - b(p2)
      ; Calcul final avec facteur de division
      a1 = (ax1 * div) >> 23
      r1 = (rx1 * div) >> 23
      g1 = (gx1 * div) >> 23
      b1 = (bx1 * div) >> 23
      ; Écriture dans le buffer temporaire
      *dstPixel = *param\addr[1] + ((j * lg + i) << 2)
      *dstPixel\l = (a1 << 24) | (r1 << 16) | (g1 << 8) | b1
    Next
  Next
  ; Libération des tableaux
  FreeArray(a())
  FreeArray(r())
  FreeArray(g())
  FreeArray(b())
EndProcedure

Procedure Guillossien_boucle(*param.parametre)
EndProcedure

Procedure Guillossien(*param.parametre)
  If param\info_active
    param\typ = #FilterType_Blur
    param\subtype = #Blur_Classic
    param\name = "Guillossien"
    param\remarque = "Blur Box optimise"
    param\info[0] = "Rayon X"           ; Rayon horizontal
    param\info[1] = "Rayon Y"           ; Rayon vertical
    param\info[2] = "Nombre de passe"   ; Nombre d’itérations du filtre
    param\info[3] = "bord"              ; Mode bord ou boucle
    param\info[4] = "Masque binaire"    ; Option masque binaire
    param\info_data(0,0) = 1 : param\info_data(0,1) = 63 : param\info_data(0,2) = 1
    param\info_data(1,0) = 1 : param\info_data(1,1) = 63 : param\info_data(1,2) = 1
    param\info_data(2,0) = 1 : param\info_data(2,1) = 3   : param\info_data(2,2) = 1
    param\info_data(3,0) = 0 : param\info_data(3,1) = 1   : param\info_data(3,2) = 0
    param\info_data(4,0) = 0 : param\info_data(4,1) = 2   : param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  
  clamp(*param\option[0], 1, 63)
  clamp(*param\option[1], 1, 63)
  clamp(*param\option[2], 1, 3)
  clamp(*param\option[3], 0, 1)
  clamp(*param\option[4], 0, 1)
  
  *param\addr[2] = 0
  *param\addr[3] = 0
  *param\addr[4] = 0
  
  ;If blur_box_Guillossien_create_limit(*param\lg, *param\ht, *param\option[0], *param\option[1], *param\option[3]) <> 0
  If blur_box_Guillossien_create_limit(*param.parametre) <> 0
      
    Filter_BufferPrepare(*param.parametre)
    CopyMemory(*param\addr[0], *param\addr[1], *param\lg * *param\ht * 4)
    
    Protected *tempo2 = AllocateMemory(*param\lg * *param\ht * 4)
    If *tempo2 <> 0
      CopyMemory(*param\addr[0], *tempo2, *param\lg * *param\ht * 4)
      
      param\addr[0] = *tempo2
      Protected passe
      For passe = 1 To *param\option[2]
        MultiThread_MT(@blur_box_Guillossien_MT(),2)
        Swap *param\addr[0] , *param\addr[1]
      Next
      If (*param\option[2] And 1) = 1   ; si le nombre de passes est impair
        CopyMemory(param\addr[0], param\addr[1], (*param\lg) * (*param\ht) * 4)
      EndIf
      FreeMemory(*tempo2)
      macro_Filter_BufferFinalize(4)
    EndIf
    
  EndIf
  If *param\addr[2] <> 0 : FreeMemory(*param\addr[2]) : EndIf
  
  
EndProcedure


; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 167
; FirstLine = 114
; Folding = -
; EnableXP
; DPIAware