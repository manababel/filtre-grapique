
Macro blur_box_create_limit_sp0(opt , tail , vers)
  e = (tail - 1) + ( 2 * opt )
  For i = 0 To e : *pointeur#vers\l[i] = (i + tail - opt) % tail : Next
EndMacro

Macro blur_box_create_limit_sp1(opt , tail , vers)
  e = tail + (2 * opt) - 1
  For i = 0 To e : ii = i - opt : clamp( ii , 0 , (tail - 1)) : *pointeur#vers\l[i] = ii : Next
EndMacro

Procedure blur_box_create_limit(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected.l lg = \image_lg[0]              ; largeur de l'image
    Protected.l ht = \image_ht[0]              ; hauteur de l'image
    Protected.l optx = \option[0]
    Protected.l opty = \option[1]
    Protected *pointeur1.Array32 = \addr[2]
    Protected *pointeur2.Array32 = \addr[3]
    Protected.l i, e, ii
    If \option[3] ; Pré-calcul des indices pour gestion des bords
      blur_box_create_limit_sp0(optx , lg , 1)
      blur_box_create_limit_sp0(opty , ht , 2)
    Else ; Mode bord : pixels répétés aux extrémités   
      blur_box_create_limit_sp1(optx , lg , 1)
      blur_box_create_limit_sp1(opty , ht , 2)
    EndIf 
  EndWith
EndProcedure
;-- 
Macro BoxBlur_declare_variable(optz , v2 , v3)
  Protected.l lg = *FilterCtx\image_lg[0]              ; largeur de l'image
  Protected.l ht = *FilterCtx\image_ht[0]              ; hauteur de l'image
  Protected.l a, r, g, b, i                            ; accumulation des composantes ARGB
  Protected.l x = 0, y = 0                             ; coordonnées dans l'image
  Protected.l pixel                                    ; pixel temporaire et index
  Protected *src.PixelArray32                          ; pointeur vers pixel de sortie
  Protected.l pixel_out, pixel_in
  Protected *dst.PixelArray32 =  *FilterCtx\addr[1]    ; pointeur vers pixel de sortie
  Protected.l optz = *FilterCtx\option[v2]
  Protected *pz.array32 = *FilterCtx\addr[v3]
  optz = (optz << 1) + 1
  Protected.l blur = 65536 / optz
  Protected *pointeur.Array32 = *FilterCtx\addr[v3]
EndMacro

Macro BoxBlur_Calcul_noyau(var)
  a = 0 : r = 0 : g = 0 : b = 0
  For i = 0 To var - 1
    pixel = *src\pixel[*pz\l[i]]
    a + ((pixel >> 24) & $FF)
    r + ((pixel >> 16) & $FF)
    g + ((pixel >> 8)  & $FF)
    b + ( pixel        & $FF)
  Next
EndMacro

Macro BoxBlur_Calcul_differentiel(var1 , var2)
  pixel_out = *src\pixel[*pointeur\l[var1 ]]
  pixel_in  = *src\pixel[*pointeur\l[var1 + var2]]
  a + ( pixel_in >> 24       ) -  (pixel_out >> 24)
  r + ((pixel_in >> 16) & $FF) - ((pixel_out >> 16) & $FF)
  g + ((pixel_in >>  8) & $FF) - ((pixel_out >>  8) & $FF)
  b + ( pixel_in        & $FF) -  (pixel_out        & $FF)
  *dst\pixel[lg * y + x] = ((a * blur) & $FF0000) << 8 | ((r * blur) & $FF0000) | ((g * blur) & $FF0000) >> 8 | ((b * blur) >> 16)
EndMacro


; Applique un flou horizontal avec traitement par blocs
Procedure BoxBlur_X(*FilterCtx.FilterParams) 
  BoxBlur_declare_variable(optx , 0 , 2)
  macro_calul_tread(ht) 
  For y = thread_start To thread_stop -1
    *src = *FilterCtx\addr[0] + ((lg * y) << 2)
    BoxBlur_Calcul_noyau(optx)
    *dst\pixel[lg * y] = (((a * blur)+ 32768) & $FF0000) << 8 | (((r * blur)+ 32768) & $FF0000) | (((g * blur)+ 32768) & $FF0000) >> 8 | (((b * blur)+ 32768) >> 16)
    For x = 0 To lg - 1 : BoxBlur_Calcul_differentiel(x , optx) : Next
  Next
EndProcedure

; Applique un flou vertical avec traitement par blocs
Procedure BoxBlur_Y(*FilterCtx.FilterParams) 
  BoxBlur_declare_variable(opty , 1 , 3)
  macro_calul_tread(lg) ; On parallélise sur la largeur (X) ou la hauteur (Y) selon ta macro
  
  ; On va stocker l'accumulateur (le noyau) pour CHAQUE colonne de la bande de thread.
  ; Au lieu d'un seul 'a, r, g, b', on crée des tableaux pour maintenir la somme courante de chaque colonne.
  Protected.l size_x = (thread_stop - thread_start)
  Protected Dim arr_a(size_x), Dim arr_r(size_x), Dim arr_g(size_x), Dim arr_b(size_x)
  Protected Dim current_pz(size_x)
  
  ; 1. Initialisation des noyaux verticaux pour toutes les colonnes du thread
  For x = thread_start To thread_stop - 1
    Protected.l idx_x = x - thread_start
    *src = *FilterCtx\addr[0] + (x << 2)
    
    ; Calcul du noyau initial (comme ta macro BoxBlur_Calcul_noyau mais en vertical)
    For i = 0 To opty - 1
      pixel = *src\pixel[*pz\l[i] * lg] ; Accès vertical pré-calculé
      arr_a(idx_x) + ((pixel >> 24) & $FF)
      arr_r(idx_x) + ((pixel >> 16) & $FF)
      arr_g(idx_x) + ((pixel >> 8)  & $FF)
      arr_b(idx_x) + ( pixel        & $FF)
    Next
    
    ; On applique la première ligne de sortie
    *dst\pixel[x] = ((arr_a(idx_x) * blur) & $FF0000) << 8 | ((arr_r(idx_x) * blur) & $FF0000) | ((arr_g(idx_x) * blur) & $FF0000) >> 8 | ((arr_b(idx_x) * blur) >> 16)
  Next
  
  ; 2. Algorithme différentiel ligne par ligne (Accès mémoire séquentiel !)
  For y = 0 To ht - 1
    Protected.l offset_out = *pointeur\l[y] * lg
    Protected.l offset_in  = *pointeur\l[y + opty] * lg
    
    *src = *FilterCtx\addr[0] ; Pointeur de base
    
    For x = thread_start To thread_stop - 1
      idx_x = x - thread_start
      
      pixel_out = *src\pixel[offset_out + x]
      pixel_in  = *src\pixel[offset_in + x]
      
      arr_a(idx_x) + (pixel_in >> 24) - (pixel_out >> 24)
      arr_r(idx_x) + ((pixel_in >> 16) & $FF) - ((pixel_out >> 16) & $FF)
      arr_g(idx_x) + ((pixel_in >>  8) & $FF) - ((pixel_out >>  8) & $FF)
      arr_b(idx_x) + (pixel_in         & $FF) - (pixel_out         & $FF)
      
      ; Ecriture dans la destination
      *dst\pixel[(y * lg) + x] = ((arr_a(idx_x) * blur) & $FF0000) << 8 | ((arr_r(idx_x) * blur) & $FF0000) | ((arr_g(idx_x) * blur) & $FF0000) >> 8 | ((arr_b(idx_x) * blur) >> 16)
    Next
  Next
EndProcedure

;--

Macro Blur_box_call(name , var , ad1 , ad2 )
  
  FilterCtx\addr[0] = ad1
  FilterCtx\addr[1] = ad2
  
  CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
    Debug "version _Pb"
    Create_MultiThread_MT(@BoxBlur_#var()) ; version pb pour la version 32bits
  CompilerElse
    
    CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
      Select FilterCtx\Asm
        Case 1 : Create_MultiThread_MT(@BoxBlur_SSE2_#var())
        Case 2 : Create_MultiThread_MT(@BoxBlur_SSE4_#var())
          ;Case 3 : Create_MultiThread_MT(@BoxBlur_AVX2_#var())
          ;Case 4 : Create_MultiThread_MT(@BoxBlur_AVX512_#var())
        Default :Create_MultiThread_MT(@BoxBlur_#var())
      EndSelect
      
    CompilerElse ; #PB_Compiler_Backend = #PB_Backend_C 
      
      Select FilterCtx\Asm
        Default :Create_MultiThread_MT(@BoxBlur_#var())
      EndSelect
      
    CompilerEndIf
    
  CompilerEndIf
EndMacro

;--

Procedure BoxBlurEX(*FilterCtx.FilterParams)
  
  Restore blur_box_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With FilterCtx
    Protected.l lg = \image_lg[0]
    Protected.l ht = \image_ht[0]
    Protected boucle
    ;-- Allocation mémoire pour la gestion de bords
    \addr[2] = AllocateMemory((lg + 2 * (\option[0] + 2)) * 4)
    \addr[3] = AllocateMemory((ht + 2 * (\option[1] + 2)) * 4)
    ;-- Allocation mémoire pour l'image temporaire
    \addr[4] = AllocateMemory(lg * ht * 4) ; image temporaire
    If \addr[4] And \addr[2]  And \addr[3] 
      
      blur_box_create_limit(*FilterCtx.FilterParams) ;-- cacul_des_bords
      
      ;Blur_box_call(BoxBlur_X, x , \image[0] ,\addr[1])
      
      For boucle = 0 To \option[2] - 1
        If boucle = 0 : Blur_box_call(BoxBlur_X, x , \image[0] ,\addr[4] ) : Else : Blur_box_call(BoxBlur_X, x , \image[1] ,\addr[4]) : EndIf ; passe x
        Blur_box_call(BoxBlur_Y, y , \addr[4] ,\image[1]) ; passe y
      Next
      mask_update(*FilterCtx.FilterParams , last_data)
      
    EndIf
    For boucle = 2  To 4 : If \addr[boucle] : FreeMemory(\addr[boucle]) : EndIf : Next ; Libère les zones mémoire
  EndWith
EndProcedure


Procedure BoxBlur(source , cible , mask , rx , ry , ndp = 1, bord = 0)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = rx
    \option[1] = ry
    \option[2] = ndp
    \option[3] = bord
  EndWith
  BoxBlurEX(FilterCtx.FilterParams)
EndProcedure

DataSection
  blur_box_data:
  Data.s "BoxBlur"
  Data.s "Flou Box rapide"
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
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 117
; FirstLine = 113
; Folding = --
; EnableAsm
; EnableThread
; EnableXP
; CPU = 5
; DisableDebugger