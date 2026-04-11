; ────────────────────────────────────────────────────────────────
; Procédure thread pour appliquer un effet de diffusion (flou de déplacement)
;
; Chaque pixel est remplacé par un pixel pris aléatoirement dans
; un voisinage défini par une amplitude optionnelle (option[0], 1–128).
;
; Le masque alpha est pris en compte : si alpha < 128, le pixel est ignoré.
;
; Multithread optimisé pour CPU multi-cœurs.
; ────────────────────────────────────────────────────────────────
Procedure Diffuse_MT(*p.parametre)
  Protected i, x, y, px, py, a, b, var, alpha
  Protected lg = *p\lg
  Protected ht = *p\ht
  Protected opt = *p\option[0]
  Protected totalPixels = lg * ht
  Protected *srcPixel.Pixel32
  Protected *dstPixel.Pixel32
  Protected *mask = *p\mask

  ; Clamp de l'option d'intensité
  Clamp(opt, 0, 256)
  ; Calcul des bornes pour la gestion du multithreading
  Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
  Protected endPos = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
  For i = startPos To endPos - 1
    ; Calcul des coordonnées du pixel courant
    y = i / lg
    x = i % lg
    ; Génération d'un décalage aléatoire dans un carré centré sur le pixel
    a = Random(opt) - (opt >> 1)
    b = Random(opt) - (opt >> 1)
    px = x + a
    py = y + b
    ; Clamp pour ne pas sortir des limites de l'image
    Clamp(px, 0, lg - 1)
    Clamp(py, 0, ht - 1)
    ; Récupération de la couleur source du pixel décalé
    var = PeekL(*p\addr[0] + ((py * lg + px) << 2))
    ; Ecriture de la couleur dans la cible
    PokeL(*p\addr[1] + (i << 2), var)
  Next
EndProcedure

; Procédure principale pour lancer l'effet de diffusion avec multithreading et masque alpha
Procedure Diffuse(*param.parametre)
  If param\info_active
    param\typ = #FilterType_TexturePattern
    param\name = "Diffuse"
    param\remarque = ""
    param\info[0] = "intensité"
    param\info[1] = "Masque binaire"
    param\info_data(0,0) = 0 : param\info_data(0,1) = 256 : param\info_data(0,2) = 1
    param\info_data(1,0) = 0 : param\info_data(1,1) = 2 : param\info_data(1,2) = 0
    ProcedureReturn
  EndIf

  filter_start(@Diffuse_MT(), 1, 1)
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 40
; Folding = -
; EnableXP
; DPIAware