; ==============================================================================
; FILTRE FLIPH (MIROIR HORIZONTAL) - STRUCTURE RÉVISÉE
; ==============================================================================

Procedure FlipH_MT(*p.FilterParams)
  With *p
    Protected start.i, stop.i
    Protected pix.l
    Protected lg.i = \image_lg[0]
    Protected ht.i = \image_ht[0]
    Protected x.i, y.i, x_miroir.i
    Protected ligne_source.i, ligne_cible.i
    
    ; --- Configuration Multithreading (macro_calcul_thread) ---
    start = (\thread_pos * ht) / \thread_max
    stop  = ((\thread_pos + 1) * ht) / \thread_max - 1
    If stop > ht - 1 : stop = ht - 1 : EndIf
    
    ; --- Traitement principal ---
    For y = start To stop
      ligne_source = \addr[0] + y * lg * 4
      ligne_cible  = \addr[1] + y * lg * 4
      
      ; Parcours optimisé : x_miroir décrémente au lieu de calculer (lg - 1 - x)
      x_miroir = lg - 1
      For x = 0 To lg - 1
        pix = PeekL(ligne_source + x * 4)
        PokeL(ligne_cible + x_miroir * 4, pix)
        x_miroir - 1 
      Next x
    Next y
  EndWith
EndProcedure

Procedure FlipHEx(*FilterCtx.FilterParams)
  Restore FlipH_Data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  With *FilterCtx
    Create_MultiThread_MT(@FlipH_MT())
    mask_update(*FilterCtx, last_data)
  EndWith
EndProcedure

Procedure FlipH(source, cible, mask)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  ; Aucune option spécifique pour ce filtre
  FlipHEx(FilterCtx)
EndProcedure

DataSection
  FlipH_Data:
  Data.s "FlipH"
  Data.s "Inverse l'image horizontalement (effet miroir)"
  Data.i #FilterType_Deformation, #Artistic_Other
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 57
; FirstLine = 8
; Folding = -
; EnableXP
; DPIAware