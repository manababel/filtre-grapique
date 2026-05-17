; ==============================================================================
; FILTRE FLIPV (MIROIR VERTICAL) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure FlipV_MT(*p.FilterParams)
  With *p
    Protected start.i, stop.i
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]
    Protected y0.i, y1.i
    Protected ligne_source.i, ligne_dest.i
    Protected taille_ligne.i
    
    ; --- Configuration Multithreading (macro_calcul_thread) ---
    start = (\thread_pos * ht) / \thread_max
    stop  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stop > ht - 1 : stop = ht - 1 : EndIf
    
    ; Précalcul de la taille d'une ligne en octets
    taille_ligne = lg * 4
    
    ; --- Traitement principal ---
    For y0 = start To stop
      ; Calculer la position miroir de la ligne
      y1 = ht - y0 - 1
      
      ; Adresses des lignes
      ligne_source = \addr[0] + y0 * taille_ligne
      ligne_dest   = \addr[1] + y1 * taille_ligne
      
      ; Copie bloc mémoire (optimisé pour le vertical)
      CopyMemory(ligne_source, ligne_dest, taille_ligne)
    Next y0
  EndWith
EndProcedure

Procedure FlipVEx(*FilterCtx.FilterParams)
  Restore FlipV_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@FlipV_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure FlipV(source, cible, mask)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  ; Aucune option spécifique pour ce filtre
  FlipVEx(FilterCtx)
EndProcedure

DataSection
  FlipV_Data:
  Data.s "FlipV"
  Data.s "Inverse l'image verticalement (haut vers bas)"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 47
; FirstLine = 10
; Folding = -
; EnableXP
; DPIAware