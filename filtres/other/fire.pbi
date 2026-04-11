Procedure fire_create_color(*fire_buffer_color)
  Protected *palPtr.pixelarray = *fire_buffer_color
  Protected.l  i
  
  For i = 0 To 31
    *palPtr\l[i +   0] = i << 1
    *palPtr\l[i +  32] = RGB(64 - (i << 1) , 0 , i << 3)
    *palPtr\l[i +  64] = RGB(   0, i << 3,              255)
    *palPtr\l[i +  96] = RGB(   i << 2 , 255 , 255)
    *palPtr\l[i + 128] = RGB(   64 + (i << 2) , 255 , 255)
    *palPtr\l[i + 160] = RGB(   128 + (i << 2) , 255 , 255)
    *palPtr\l[i + 192] = RGB(   192 + i , 255 , 255)
    *palPtr\l[i + 224] = RGB(   224 + i , 255 , 255)
  Next
EndProcedure

Procedure fire_create_seed(*fire_buffer_seed , *fire_buffer_lg , *fire_buffer_ht , *param.parametre)
  
  Protected x, y, pos
  Protected lg = *param\lg
  Protected ht = *param\ht
    
  Protected *src.PixelArray = *param\addr[0]
  Protected *seed.pixel8 = *fire_buffer_seed ; Buffer seed
  Protected v.l, w.l, i.l
  
  Protected p0,p1,p2,p3,p4
  Protected r1 , g1 , b1
  Protected r2 , g2 , b2
  Protected r3 , g3 , b3
  Protected r4 , g4 , b4
  
  ;--- ÉTAPE 1 : grayscale et egde
  For y = 1 To ht - 2
    For x = 1 To lg - 2
      pos = y * lg + x
      p1 = pos - 1 - lg
      p2 = pos + 1 - lg
      p3 = pos - 1 + lg
      p4 = pos + 1 + lg
      
      getrgb(*src\l[p1],r1,g1,b1)
      getrgb(*src\l[p2],r2,g2,b2)
      getrgb(*src\l[p3],r3,g3,b3)
      getrgb(*src\l[p4],r4,g4,b4)
      
      r1 - r4
      g1 - g4
      b1 - b4
      r2 - r3
      g2 - g3
      b2 - b3
      
      r1 = Abs(r1) + Abs(r2)
      g1 = Abs(g1) + Abs(g2)
      b1 = Abs(b1) + Abs(b2)
      
      rgbtogray(w,r1,g1,b1)
      
      w * param\option[1] * 0.1
      clamp(w , 0 , 255)
      If w > *param\option[0] : w = 255 : Else : w = 0 : EndIf
      *seed\b[pos] = w
    Next
  Next
EndProcedure

Procedure fire_update_fire_seed(*param.parametre)
  
  Protected i
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected tt = lg * ht
  Protected *seed.pixel8 = *param\addr[5]
  Protected *heat.pixel8 = *param\addr[6]
  
  Protected startPos = (*param\thread_pos * tt) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * tt) / *param\thread_max - 1
  
  For i = startPos To endPos
    If (*seed\b[i]  & 255) = 255 And (Random(100) > 70)
      *heat\b[i] = 150 + Random(105)
    EndIf 
  Next
EndProcedure

Procedure fire_update_fire_update(*param.parametre)
  Protected x , y, pos , rnd
  Protected p0 , p1 , p2 , p3 , p4
  Protected lg = *param\lg
  Protected ht = *param\ht
  Protected *heat.pixel8 = *param\addr[6]
  
  For y = 1 To ht - 2
    For x = 2 To lg - 3
      pos = y * lg + x
      p1 = *heat\b[pos - 1 - lg] & $FF
      p2 = *heat\b[pos - lg]     & $FF
      p3 = *heat\b[pos + 1 - lg] & $FF
      p4 = *heat\b[pos]          & $FF
      p0 = ((p1 + p2 + p3 + p4) >> 2) - ((5-(*param\option[2] * 0.1)) + Random(2) - 1)
      If p0 > 0
        rnd = (Random(4) - 2) + 0.5
        *heat\b[pos + rnd] = p0
      EndIf
    Next
  Next
EndProcedure

Procedure fire_update_fire_mix(*param.parametre)
  Protected.l r1, g1, b1, r2, g2, b2 , i
  Protected tt = *param\lg * *param\ht
  Protected *cible.PixelArray = *param\addr[1]
  Protected *heat.pixel8 = *param\addr[6]
  Protected *pal.PixelArray = *param\addr[7]
  
  Protected startPos = (*param\thread_pos * tt) / *param\thread_max
  Protected endPos   = ((*param\thread_pos + 1) * tt) / *param\thread_max - 1

  For i = startPos To endPos
    getrgb((*pal\l[(*heat\b[i] & $FF)]) , r1 , g1 , b1)
    getrgb(*cible\l[i] , r2 , g2 , b2)
    r1 + r2
    g1 + g2
    b1 + b2
    clamp_rgb(r1,g1,b1)
    *cible\l[i] = (r1 << 16) | (g1 << 8) | b1
  Next

EndProcedure

Procedure fire_update_fire(*fire_buffer_upate , *fire_buffer_seed , *fire_buffer_color , *param.parametre)
  
  *param\addr[5] = *fire_buffer_seed
  *param\addr[6] = *fire_buffer_upate
  *param\addr[7] = *fire_buffer_color
  
  MultiThread_MT(@fire_update_fire_seed() , 2)
  
  fire_update_fire_update(*param.parametre)
 
  MultiThread_MT(@fire_update_fire_mix() , 2)
EndProcedure
  


Procedure fire(*param.parametre)
  
  Static *fire_buffer_lg = 0
  Static *fire_buffer_ht = 0
  
  Static *fire_buffer_seed = 0
  Static *fire_buffer_upate = 0
  Static *fire_buffer_color = 0
  Static fire_mem0.f = 0
  Static fire_mem1.f = 0
  Static fire_mem2.f = 0
  
  Protected.i nombre_de_donnees , j
  Protected r , g , b
  Protected.f h , s , i , t
  Protected.f rv , gv , bv
  
  If *param\info_active
    Restore fire_data         ; selectionne la position du pointer des donnes
    Read.i nombre_de_donnees  ; lit le nombre de donnees a lire
    Read.s *param\name
    Read.s *param\remarque
    Read.i *param\typ
    Read.i *param\subtype
    For j = 0 To nombre_de_donnees - 1
      Read.s *param\info[j]
      Read.i *param\info_data(j,0)
      Read.i *param\info_data(j,1)
      Read.i *param\info_data(j,2)
    Next
    ProcedureReturn
  EndIf
  
  If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
  
  *param\addr[0] = *param\source
  *param\addr[1] = *param\cible
  
  If *fire_buffer_color = 0
    *fire_buffer_color = AllocateMemory(256 * 4)
    fire_create_color(*fire_buffer_color)
  EndIf  
 
  If *fire_buffer_seed = 0
    *fire_buffer_seed = AllocateMemory(*param\lg * *param\ht)
    *fire_buffer_lg = *param\lg
    *fire_buffer_ht = *param\ht
    fire_create_seed(*fire_buffer_seed , *fire_buffer_lg , *fire_buffer_ht , *param.parametre)
  Else
    If *fire_buffer_lg <> *param\lg Or *fire_buffer_ht = *param\ht
      FreeMemory(*fire_buffer_seed)
      *fire_buffer_seed = AllocateMemory(*param\lg * *param\ht)
      *fire_buffer_lg = *param\lg
      *fire_buffer_ht = *param\ht
    EndIf
    
    If fire_mem0 <> *param\option[0] Or fire_mem1 <> *param\option[1] Or fire_mem2 <> *param\option[2]
      fire_mem0 = *param\option[0]
      fire_mem1 = *param\option[1]
      fire_mem2 = *param\option[2]
      fire_create_seed(*fire_buffer_seed , *fire_buffer_lg , *fire_buffer_ht , *param.parametre)
    EndIf
  EndIf

  
  If *fire_buffer_upate = 0
    *fire_buffer_upate = AllocateMemory(*param\lg * *param\ht)
  EndIf  
  
  If *fire_buffer_color And *fire_buffer_seed And *fire_buffer_upate; On vérifie que l'allocation a réussi
    fire_update_fire(*fire_buffer_upate , *fire_buffer_seed , *fire_buffer_color , *param.parametre)
  EndIf
  
  
EndProcedure

DataSection
  fire_data:
  Data.i 4; nombre de donnees
  Data.s "Fire"
  Data.s "effet de feu"
  
  Data.i #FilterType_Other
  Data.i #Blur_Classic
  
  Data.s "seuil"
  Data.i 1,254,127
  Data.s "mul"
  Data.i 1 , 20 , 10
  Data.s "life"
  Data.i 1,50,25
  Data.s "Masque binaire"    ; Option masque binaire
  Data.i 0,2,0
EndDataSection
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 209
; FirstLine = 178
; Folding = --
; EnableXP
; DPIAware