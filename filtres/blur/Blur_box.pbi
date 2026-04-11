
Macro BoxBlur_declare_variable(lenght , name , var1 , var2 , size)
  Protected.l lg = *param\lg               ; largeur de l'image
  Protected.l ht = *param\ht               ; hauteur de l'image
  Protected.l a, r, g, b, i                ; accumulation des composantes ARGB
  Protected.l x = 0, y = 0                 ; coordonnées dans l'image
  Protected.l pixel                        ; pixel temporaire et index
  Protected *src.Pixel32
  Protected *dst.Pixel32                   ; pointeur vers pixel de sortie
  macro_calul_tread(lenght)                ; calcule la portion d'image à traiter pour chaque thread
  
  
  Protected *copy_src.Pixel32
  Protected *copy_dst.Pixel32
  Protected *pId
  
  Protected.l name = *param\option[var1]
  Protected pz = *param\addr[var2]
  name = (name << 1) + 1
  Protected.l blur = 65536 / name
  Protected.l pixel_out, pixel_in
EndMacro

Macro BoxBlur_Calcul_noyau(var)
  *pId = pz
  a = 0 : r = 0 : g = 0 : b = 0
  For i = 0 To var - 1
    pixel = PeekL(*src + (PeekL(*pId) << 2))
    a + ((pixel >> 24) & $FF)
    r + ((pixel >> 16) & $FF)
    g + ((pixel >> 8)  & $FF)
    b + ( pixel        & $FF)
    *pId + 4
  Next
EndMacro

Macro BoxBlur_Ecrire_pixel()
  *dst\l = ((a * blur) & $FF0000) << 8 | 
           ((r * blur) & $FF0000) | 
           ((g * blur) & $FF0000) >> 8 | 
           ((b * blur) >> 16)
EndMacro

Macro BoxBlur_Calcul_differentiel(var1 , var2)
  pixel_out = PeekL(*src +(PeekL(pz + ((var1 - 1       ) << 2)) << 2))
  pixel_in  = PeekL(*src +(PeekL(pz + ((var1 - 1 + var2) << 2)) << 2))
  a + ( pixel_in  >> 24      ) -  (pixel_out >> 24)
  r + ((pixel_in >> 16) & $FF) - ((pixel_out >> 16) & $FF)
  g + ((pixel_in >>  8) & $FF) - ((pixel_out >>  8) & $FF)
  b + ( pixel_in        & $FF) -  (pixel_out        & $FF)
  *dst = *param\addr[1] + (((lg * y) + x) << 2)
  BoxBlur_Ecrire_pixel()
EndMacro

; Applique un flou horizontal avec traitement par blocs
Procedure BoxBlur_X(*param.parametre) 
  BoxBlur_declare_variable(ht , optx , 0 , 2 , lg)
  ; Traiter par blocs de lignes
  For y = thread_start To thread_stop -1
    ; Accumulation initiale
    *src = *param\addr[0] + ((lg * y) << 2)
    BoxBlur_Calcul_noyau(optx)
    ; Premier pixel
    *dst = *param\addr[1] + ((lg * y) << 2)
    BoxBlur_Ecrire_pixel()
    ; Pixels suivants avec fenêtre glissante
    For x = 1 To lg - 1
      BoxBlur_Calcul_differentiel(x , optx)
    Next
  Next
EndProcedure

; Applique un flou vertical avec traitement par blocs
Procedure BoxBlur_Y(*param.parametre) 
  BoxBlur_declare_variable(lg , opty , 1 , 3 , ht)
  ; Allouer un buffer local pour ce thread (évite les conflits multi-thread)
  Protected *ligne = AllocateMemory(ht * 4 )
  If *ligne = 0 : ProcedureReturn : EndIf
  
  For x = thread_start To thread_stop - 1
    ; Copie de la colonne courante
    *copy_src.Pixel32 = *param\addr[0] + (x << 2)
    *copy_dst.Pixel32 = *ligne
    For y = 0 To ht - 1
      PokeL(*copy_dst, PeekL(*copy_src))
      *copy_src + (lg << 2)
      *copy_dst + 4
    Next
    ;For y = 0 To ht - 1 : PokeL(*ligne + (y << 2), PeekL(*param\addr[0] + (((lg * y) + x) << 2))) : Next
    ; Accumulation initiale
    *src = *ligne
    BoxBlur_Calcul_noyau(opty)
    ; Premier pixel
    *dst = *param\addr[1] + (x << 2)
    BoxBlur_Ecrire_pixel()
    ; Pixels suivants avec fenêtre glissante
    For y = 1 To ht - 1
      BoxBlur_Calcul_differentiel(y , opty)
    Next
  Next
  FreeMemory(*ligne)
EndProcedure

Procedure BoxBlur_cacul_des_bords(*param.parametre) 
  Protected.l i, boucle, e, ii, l, k
  Protected.l lg = *param\lg
  Protected.l ht = *param\ht
  
  Protected.l optx = *param\option[0]
  Protected.l opty = *param\option[1]
  
  ; Pré-calcul des indices pour gestion des bords
  If *param\option[3]
    ; Mode boucle : les pixels sortants "reviennent" à l'autre extrémité
    k = optx : l = 2 * optx : e = (lg - 1) - k
    For i = 0 To (lg - 1) + l : PokeL(*param\addr[2] + (i << 2), (i + e) % lg) : Next
    k = opty : l = 2 * opty : e = (ht - 1) - k
    For i = 0 To (ht - 1) + l : PokeL(*param\addr[3] + (i << 2), (i + e) % ht) : Next
  Else      
    ; Mode bord : pixels répétés aux extrémités
    k = optx : l = 2 * optx
    For i = 0 To lg + l : ii = i - k : If ii < 0 : ii = 0 : EndIf : If ii > (lg - 1) : ii = (lg - 1) : EndIf : PokeL(*param\addr[2] + (i << 2), ii) : Next
    k = opty : l = 2 * opty
    For i = 0 To ht + l : ii = i - k : If ii < 0 : ii = 0 : EndIf : If ii > (ht - 1) : ii = (ht - 1) : EndIf : PokeL(*param\addr[3] + (i << 2), ii) : Next
  EndIf 
  
EndProcedure

Macro Blur_box_call(name,var)
  CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
    MultiThread_MT(@BoxBlur_#var(), *param\thread_max_#var)
  CompilerElse
    CompilerIf #PB_Compiler_Backend <> #PB_Backend_C
      If Asm_active = 0
        MultiThread_MT(@BoxBlur_#var(), *param\thread_max_#var)
      Else
        MultiThread_MT(@name(), *param\thread_max_#var)
      EndIf
    CompilerElse
      If Asm_active = 0
        MultiThread_MT(@BoxBlur_#var(), *param\thread_max_#var)
      Else
        MultiThread_MT(@name(), *param\thread_max_#var)
      EndIf
    CompilerEndIf
  CompilerEndIf
EndMacro

Macro Blur_box_calcul_thread(var)
  t = ElapsedMilliseconds() - t
  
  If *param\thread_time_#var = 0 
    *param\thread_time_#var = 100000000 
  EndIf
  
  If t < *param\thread_time_#var
    *param\thread_max_#var + 1
    If *param\thread_max_#var > thread_max 
      *param\thread_max_#var = thread_max 
      *param\passe_count_#var = thread_max  ; Sauvegarder
    EndIf
  Else
    *param\thread_max_#var - 1
    If *param\thread_max_#var = 0 
      *param\thread_max_#var = 1 
    EndIf
    ; On a dépassé l'optimum, sauvegarder le précédent
    If *param\passe_count_#var = 0
      *param\passe_count_#var = *param\thread_max_#var + 1
      Debug "Calibration trouvée : " + Str(*param\passe_count_#var) + " threads"
    EndIf
  EndIf
  
  *param\thread_time_#var = t
EndMacro

DataSection
  blur_box_data:
  Data.i 5; nombre de donnees
  Data.s "Blur_box"
  Data.s "Flou Box rapide (optimisé multi-thread + cache-friendly)"
  Data.i #FilterType_Blur
  Data.i #Blur_Classic
  
  Data.s "Rayon X"           ; Rayon horizontal
  Data.i 1,100,1
  Data.s "Rayon Y"           ; Rayon vertical
  Data.i 1,100,1
  Data.s "Nombre de passe"   ; Nombre d'itérations du filtre
  Data.i 1,3,1
  Data.s "bord"              ; Mode bord ou boucle
  Data.i 0,1,0
  Data.s "Masque binaire"    ; Option masque binaire
  Data.i 0,2,0
  
EndDataSection

Procedure Blur_box(*param.parametre)
  ; Mode interface : renseigner les informations sur les options si demandé
  DetectCPU()
  Debug asm_type
  If *param\info_active
    *param\typ = #FilterType_Blur
    *param\subtype = #Blur_Classic
    *param\name = "Blur_box"
    *param\remarque = "Flou Box rapide (optimisé multi-thread + cache-friendly)"
    *param\info[0] = "Rayon X"           ; Rayon horizontal
    *param\info[1] = "Rayon Y"           ; Rayon vertical
    *param\info[2] = "Nombre de passe"   ; Nombre d'itérations du filtre
    *param\info[3] = "bord"              ; Mode bord ou boucle
    *param\info[4] = "Masque binaire"    ; Option masque binaire
    *param\info_data(0,0) = 1 : *param\info_data(0,1) = 100 : *param\info_data(0,2) = 1
    *param\info_data(1,0) = 1 : *param\info_data(1,1) = 100 : *param\info_data(1,2) = 1
    *param\info_data(2,0) = 1 : *param\info_data(2,1) = 3   : *param\info_data(2,2) = 1
    *param\info_data(3,0) = 0 : *param\info_data(3,1) = 1   : *param\info_data(3,2) = 0
    *param\info_data(4,0) = 0 : *param\info_data(4,1) = 2   : *param\info_data(4,2) = 0
    ProcedureReturn
  EndIf
  
  clamp(*param\option[0], 1, 100)
  clamp(*param\option[1], 1, 100)
  clamp(*param\option[2], 1, 3)
  
  ; Allocation mémoire pour la gestion de bords
  *param\addr[2] = AllocateMemory((*param\lg + 2 * (*param\option[0] + 2)) * 4)
  *param\addr[3] = AllocateMemory((*param\ht + 2 * (*param\option[1] + 2)) * 4)
  
  *param\tempo = AllocateMemory(*param\lg * *param\ht * 4)
  If *param\tempo = 0 Or *param\addr[2] = 0 Or *param\addr[3] = 0
    If *param\tempo : FreeMemory(*param\tempo) : EndIf
    If *param\addr[2] : FreeMemory(*param\addr[2]) : EndIf
    If *param\addr[3] : FreeMemory(*param\addr[3]) : EndIf
    ProcedureReturn
  EndIf
  
  BoxBlur_cacul_des_bords(*param.parametre) 
    
; --- Incrémenter le nombre de threads ---
If *param\thread_max_x = 0 : *param\thread_max_x = 1 : EndIf
If *param\thread_max_y = 0 : *param\thread_max_y = 1 : EndIf


; --- Buffers pour ping-pong (sans toucher à source) ---
Protected *buf_read = *param\source
Protected *buf_write = *param\cible
Protected *buf_swap

; --- Variables de temps ---
Protected t
Protected thread_max = CountCPUs()

; --- Boucle multi-pass ---
Protected boucle
For boucle = 1 To *param\option[2]
  
  ; ---- Passe X ----
  *param\addr[0] = *buf_read
  *param\addr[1] = *param\tempo
  t = ElapsedMilliseconds()
 ; *param\thread_max_x = 1
  Blur_box_call(BoxBlur_X, x)
  Blur_box_calcul_thread(x)

  ; ---- Passe Y ----
  *param\addr[0] = *param\tempo
  *param\addr[1] = *buf_write
  t = ElapsedMilliseconds()
 ; *param\thread_max_y = 1
  Blur_box_call(BoxBlur_Y, y)
  Blur_box_calcul_thread(y)
  
  ; ---- Swap buffers pour la passe suivante (sauf si dernière passe) ----
  If boucle < *param\option[2]
    *buf_swap = *buf_read
    *buf_read = *buf_write
    *buf_write = *buf_swap
  EndIf
Next

; ---- Mise à jour du temps total ----
*param\thread_total_time = *param\thread_time_x + *param\thread_time_y

Debug "temps total: " + Str(*param\thread_total_time) + " ms"
Debug "  - temps X: " + Str(*param\thread_time_x) + " ms (" + Str(*param\thread_max_x) + " threads)"
Debug "  - temps Y: " + Str(*param\thread_time_y) + " ms (" + Str(*param\thread_max_y) + " threads)"
Debug "---"

  If *param\mask And *param\option[4] : *param\mask_type = *param\option[4] - 1 : MultiThread_MT(@_mask()) : EndIf
  
  ; Libération mémoire
  FreeMemory(*param\tempo)
  FreeMemory(*param\addr[2])
  FreeMemory(*param\addr[3])
EndProcedure
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 202
; FirstLine = 171
; Folding = --
; EnableAsm
; EnableThread
; EnableXP
; CPU = 5
; DisableDebugger