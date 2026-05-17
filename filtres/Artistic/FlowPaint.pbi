; --- Structure pour simuler les particules du JS ---
Structure Particle
  x.f
  y.f
  fc.l
  maxFc.l
  col.l
  speed.f
EndStructure

Procedure FlowPaint_MT(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0]
    Protected ht = \image_ht[0]
    
    ; On divise le nombre total de particules par le nombre de threads
    ; pour respecter la densité choisie dans l'interface.
    Protected nbParticles = \option[0] ;/ \thread_count 
    Protected speed.f = \option[1] / 10.0 ; Ajustement pour plus de finesse
    
    Protected i, step_count, px, py, index, targetIndex
    Protected angle.f, noise_scale.f = 0.005
    
    Dim p.Particle(nbParticles)
    
    ; Initialisation des particules
    For i = 0 To nbParticles
      p(i)\x = Random(lg - 1)
      p(i)\y = Random(ht - 1)
      p(i)\maxFc = Random(40, 15)
      p(i)\speed = speed
    Next
    
    ; Simulation du mouvement
    For step_count = 0 To 500
      For i = 0 To nbParticles
        
        px = Int(p(i)\x) : py = Int(p(i)\y)
        
        If px >= 0 And px < lg And py >= 0 And py < ht
          ; 1. Prélèvement de la couleur (Source)
          index = (py * lg + px) << 2
          p(i)\col = PeekL(\addr[0] + index)
          
          ; 2. Champ de force (Flow Field)
          ; Utilisation de Sin/Cos pour créer des tourbillons
          angle = (Sin(p(i)\x * noise_scale) + Cos(p(i)\y * noise_scale)) * #PI * 2
          
          p(i)\x + Cos(angle) * p(i)\speed
          p(i)\y + Sin(angle) * p(i)\speed
          
          ; 3. Dessin du "pinceau" (Carré de 2x2 pixels)
          Protected dx, dy, tx, ty
          For dy = 0 To 1
            For dx = 0 To 1
              tx = Int(p(i)\x) + dx
              ty = Int(p(i)\y) + dy
              
              If tx >= 0 And tx < lg And ty >= 0 And ty < ht
                targetIndex = (ty * lg + tx) << 2
                ; Optionnel : Ajouter ici un calcul d'Alpha Blending pour la douceur
                PokeL(\addr[1] + targetIndex, p(i)\col)
              EndIf
            Next
          Next
        EndIf
        
        ; Gestion du cycle de vie (Reset si trop vieille ou hors image)
        p(i)\fc + 1
        If p(i)\fc > p(i)\maxFc Or p(i)\x < 0 Or p(i)\x >= lg Or p(i)\y < 0 Or p(i)\y >= ht
          p(i)\x = Random(lg - 1)
          p(i)\y = Random(ht - 1)
          p(i)\fc = 0
        EndIf
      Next
    Next
  EndWith
EndProcedure

Procedure FlowPaintEx(*FilterCtx.FilterParams)
  Restore FlowPaint_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  Create_MultiThread_MT(@FlowPaint_MT())
  
  mask_update(*FilterCtx.FilterParams , last_data)
  
EndProcedure

Procedure FlowPaint(source , cible , mask , densite, vit)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = densite
    \option[1] = vit
  EndWith
  FlowPaintEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  FlowPaint_data:
  Data.s "FlowPaint (marche pas)"
  Data.s "Peinture générative par flux de particules"
  Data.i #FilterType_Artistic
  Data.i #Artistic_Material
  
  Data.s "Densité"        ; Correspond au nombre de particules
  Data.i 100, 1000, 500
  Data.s "Vitesse"        ; Vitesse de déplacement
  Data.i 1, 100, 2
  Data.s "XXX"  
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 30
; Folding = -
; EnableXP
; DPIAware