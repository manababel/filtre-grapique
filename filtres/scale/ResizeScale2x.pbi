; ===== Scale2x Resize (Multithread) =====
; Basé sur l'algorithme d'Andrea Mazzoleni

Procedure ResizeScale2x_sp(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg_src = \image_lg[0]
    Protected ht_src = \image_ht[0]
    Protected lg_dst = \image_lg[1]
    Protected ht_dst = \image_ht[1]
    
    Protected x, y
    
    ; Voisinage immédiat (4-connectivité)
    ;       [B]
    ;   [D] [E] [F]
    ;       [H]
    Protected.Pixel32 *E, *B, *D, *F, *H
    
    ; Variables d'adresses pour l'écriture ultra-rapide
    Protected *line_dst_top.Pixel32
    Protected *line_dst_bottom.Pixel32
    
    ; CORRECTION : Pointeurs intermédiaires pour les pixels de droite (P1 et P3)
    Protected *P1.Pixel32
    Protected *P3.Pixel32
    
    Protected.i pitch_dst = lg_dst << 2 ; Taille en octets d'une ligne de destination
    
    macro_calul_tread(ht_src)
    
    For y = thread_start To thread_stop - 1
      ; OPTIMISATION : On calcule le pointeur de début pour les deux lignes cibles (bloc 2x2)
      *line_dst_top    = \addr[1] + ((y * 2) * lg_dst << 2)
      *line_dst_bottom = *line_dst_top + pitch_dst
      
      ; Pointeur de départ de la ligne source
      *E = \addr[0] + ((y * lg_src) << 2)
      
      For x = 0 To lg_src - 1
        
        ; 1. Récupération des voisins avec clamping
        If y > 0 : *B = *E - (lg_src << 2) : Else : *B = *E : EndIf
        If y < ht_src - 1 : *H = *E + (lg_src << 2) : Else : *H = *E : EndIf
        If x > 0 : *D = *E - 4 : Else : *D = *E : EndIf
        If x < lg_src - 1 : *F = *E + 4 : Else : *F = *E : EndIf
        
        ; CORRECTION : On cale P1 et P3 exactement 4 octets après le pixel de gauche
        *P1 = *line_dst_top + 4
        *P3 = *line_dst_bottom + 4
        
        ; 2. Logique Scale2x & Écriture directe
        
        ; --- P0 (Haut-Gauche) ---
        If *B\l = *D\l And *B\l <> *H\l And *D\l <> *F\l
          *line_dst_top\l = *D\l
        Else
          *line_dst_top\l = *E\l
        EndIf
        
        ; --- P1 (Haut-Droite) ---
        If *B\l = *F\l And *B\l <> *H\l And *F\l <> *D\l
          *P1\l = *F\l
        Else
          *P1\l = *E\l
        EndIf
        
        ; --- P2 (Bas-Gauche) ---
        If *D\l = *H\l And *D\l <> *B\l And *H\l <> *F\l
          *line_dst_bottom\l = *D\l
        Else
          *line_dst_bottom\l = *E\l
        EndIf
        
        ; --- P3 (Bas-Droite) ---
        If *H\l = *F\l And *H\l <> *B\l And *F\l <> *D\l
          *P3\l = *F\l
        Else
          *P3\l = *E\l
        EndIf
        
        ; Avancement des pointeurs (On saute de 2 pixels en destination = 8 octets)
        *E + 4
        *line_dst_top + 8
        *line_dst_bottom + 8
        
      Next x
    Next y
  EndWith
EndProcedure

; ===== Procédure Ex =====
Procedure ResizeScale2xEx(*FilterCtx.FilterParams)
  Restore ResizeScale2x_data
  ; Ajout du paramètre 1 car la taille source et cible est différente (doublement de taille)
  Protected last_data = Filter_InitAndValidate(1) 
  If last_data < 0 : ProcedureReturn 0 : EndIf
  Create_MultiThread_MT(@ResizeScale2x_sp())
EndProcedure

; ===== Appel simplifié =====
Procedure ResizeScale2x(source, cible)
  Set_Source(source)
  Set_Cible(cible)
  ResizeScale2xEx(FilterCtx)
EndProcedure

DataSection
  ResizeScale2x_data:
  Data.s "ResizeScale2x"
  Data.s "Scale2x (Simple & Rapide)"
  Data.i #FilterType_resize
  Data.i 0 
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 102
; FirstLine = 58
; Folding = -
; EnableXP
; DPIAware