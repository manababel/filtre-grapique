UseGIFImageDecoder()
UseJPEG2000ImageDecoder()
UseJPEG2000ImageEncoder()
UseJPEGImageDecoder()
UseJPEGImageEncoder()
UsePNGImageDecoder()
UsePNGImageEncoder()
UseTGAImageDecoder()
UseTIFFImageDecoder()

DeclareModule filtres
  
  ;-- constantes
  ;{ 
  ;===============================
  ;-- TYPES DE FILTRES (Catégories principales)
  ;===============================
  Enumeration
    #FilterType_Blur = 1           ; Flous et atténuations
    #FilterType_EdgeDetection      ; Détection de contours
    #FilterType_Dithering          ; Tramage et quantification
    #FilterType_ColorAdjustment    ; Réglages couleurs (luminosité, contraste, etc.)
    #FilterType_ColorEffect        ; Effets colorimétriques (sépia, N&B, etc.)
    #FilterType_Artistic           ; Effets artistiques (HDR, Glow, Crayon, etc.)
    #FilterType_TexturePattern     ; Textures et mosaïques
    #FilterType_Texture            ; Textures
    #FilterType_Deformation        ; Transformations géométriques
    #FilterType_Convolution        ; Convolution personnalisée
    #FilterType_ColorSpace         ; Conversion d'espaces de couleur
    #FilterType_BlendModes         ; Modes de fusion / Mix
    #FilterType_resize             ; redimensionne une image
    #FilterType_Other              ; Divers
  EndEnumeration
  
  ;===============================
  ;-- SOUS-TYPES DE FILTRES (Classification fine)
  ;===============================
  Enumeration
    ; ═══════════════════════════════
    ; BLUR - 12 sous-catégories
    ; ═══════════════════════════════
    #Blur_Classic                  ; Flous basiques et rapides
    #Blur_Gaussian                 ; Variantes gaussiennes
    #Blur_Directional              ; Flous orientés et de mouvement
    #Blur_EdgeAware                ; Préservation des contours
    #Blur_Adaptive                 ; Adaptatifs et contextuels
    #Blur_Stochastic               ; Échantillonnage aléatoire
    #Blur_Optical                  ; Simulation optique et DOF
    #Blur_MultiScale               ; Pyramides et multi-résolution
    #Blur_Morphological            ; Opérations morphologiques
    #Blur_Artistic                 ; Effets créatifs et artistiques
    #Blur_Specialized              ; Cas spécialisés (sharpening, etc.)
    #Blur_Advanced                 ; Algorithmes avancés
    
    ; ═══════════════════════════════
    ; EDGE DETECTION - 6 sous-catégories
    ; ═══════════════════════════════
    #EdgeDetect_Gradient           ; Dérivées premières (Sobel, Prewitt, etc.)
    #EdgeDetect_Laplacian          ; Dérivées secondes (LoG, DoG, etc.)
    #EdgeDetect_Advanced           ; Méthodes sophistiquées (Canny, Phase Congruency)
    #EdgeDetect_Morphological      ; Gradients morphologiques
    #EdgeDetect_MultiScale         ; Détection multi-échelle
    #EdgeDetect_Specialized        ; Méthodes spécialisées (couleur, texture, etc.)
    
    ; ═══════════════════════════════
    ; DITHERING - 6 sous-catégories
    ; ═══════════════════════════════
    #Dither_ErrorDiffusion         ; Diffusion d'erreur (Floyd-Steinberg, etc.)
    #Dither_Ordered                ; Matrices ordonnées (Bayer, etc.)
    #Dither_Random                 ; Bruit aléatoire pur
    #Dither_Stochastic             ; Bruit structuré (blue noise, etc.)
    #Dither_Adaptive               ; Adaptatif au contenu
    #Dither_Hybrid                 ; Méthodes hybrides et space-filling curves
    #Dither_Fast
    
    ; ═══════════════════════════════
    ; COLOR ADJUSTMENT - 2 sous-catégories
    ; ═══════════════════════════════
    #ColorAdjust_Basic             ; Réglages de base (luminosité, contraste, etc.)
    #ColorAdjust_Advanced          ; Réglages avancés (balance, exposition, etc.)
    
    ; ═══════════════════════════════
    ; COLOR EFFECTS - 4 sous-catégories
    ; ═══════════════════════════════
    #ColorEffect_Mono              ; Conversion monochrome (N&B, gris)
    #ColorEffect_Toning            ; Virage et colorisation (sépia, teinte)
    #ColorEffect_Manipulation      ; Manipulation créative (posterize, etc.)
    #ColorEffect_Selective         ; Effets sélectifs par canal/teinte
    
    ; ═══════════════════════════════
    ; ARTISTIC - 3 sous-catégories
    ; ═══════════════════════════════
    #Artistic_Light                ; Effets de lumière (glow, HDR, etc.)
    #Artistic_Material             ; Simulation matériaux (crayon, fusain, etc.)
    #Artistic_Other                ; Autres effets artistiques
    
    ; ═══════════════════════════════
    ; TEXTURE & PATTERN - 3 sous-catégories
    ; ═══════════════════════════════
    #Texture_Mosaic                ; Mosaïques et pavages
    #Texture_Detail                ; Détails et perturbations
    #Texture_Relief                ; Relief et embossage
    
    ; ═══════════════════════════════
    ; DEFORMATION - 5 sous-catégories
    ; ═══════════════════════════════
    #Deform_Basic                  ; Transformations de base (flip, rotate, etc.)
    #Deform_Projection             ; Projections et perspectives
    #Deform_Radial                 ; Déformations radiales (spherize, etc.)
    #Deform_Wave                   ; Ondulations et ripples
    #Deform_Advanced               ; Déformations avancées (liquify, mesh warp, etc.)
    
    ; ═══════════════════════════════
    ; CONVOLUTION - 1 sous-catégorie
    ; ═══════════════════════════════
    #Convolution_3x3           
    #Convolution_5x5
    #Convolution_7x7
    
    ; ═══════════════════════════════
    ; COLOR SPACE - 4 sous-catégories
    ; ═══════════════════════════════
    #ColorSpace_YUV                ; Conversions RGB ↔ YUV
    #ColorSpace_YIQ                ; Conversions RGB ↔ YIQ
    #ColorSpace_LAB                ; Conversions RGB ↔ LAB
    #ColorSpace_Other              ; Autres espaces (HSV, HSL, etc.)
    
    ; ═══════════════════════════════
    ; BLEND MODES - 6 sous-catégories
    ; ═══════════════════════════════
    #Blend_Additive                ; Modes additifs
    #Blend_Subtractive             ; Modes soustractifs
    #Blend_Multiply                ; Modes multiplicatifs
    #Blend_Contrast                ; Modes de contraste
    #Blend_Soft                    ; Modes doux
    #Blend_Hard                    ; Modes durs
    
    ; ═══════════════════════════════
    ; OTHER - 1 sous-catégorie
    ; ═══════════════════════════════
    #Other_Misc                    ; Divers non classés
    
  EndEnumeration
  
  ;===============================
  ;-- FILTRES INDIVIDUELS
  ;===============================
  Enumeration
    
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ BLUR FILTERS
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    
    ; ─── Blur_Classic ───
    #Filter_BoxBlur                     ; Box blur ultra-rapide | CPU: ★★★★★ | MEM: ★★★★★
    #Filter_Guillossien                 ; Box blur optimisé | CPU: ★★★★★ | MEM: ★★★★★
    #Filter_SummedArea
    #Filter_Blur_IIR                    ; Flou exponentiel récursif | CPU: ★★★★★ | MEM: ★★★★★
    #Filter_StackBlur                   ; Stack blur (approx. gaussienne) | CPU: ★★★★☆ | MEM: ★★★★☆
    #Filter_CircularMeanBlur            ; Moyenne circulaire isotrope | CPU: ★★★★☆ | MEM: ★★★★☆
    
    ; ─── Blur_Gaussian ───
    #Filter_GaussianBlur_Conv           ; Gaussien par convolution | CPU: ★★★☆☆ | MEM: ★★★★☆
    #Filter_SeparableGaussian           ; Gaussien séparable optimisé | CPU: ★★★★☆ | MEM: ★★★★☆
    #Filter_HeatDiffusionBlur           ; Diffusion thermique itérative | CPU: ★★★☆☆ | MEM: ★★★★☆
    
    ; ─── Blur_Directional ───
    #Filter_MotionBlur                  ; Flou de mouvement linéaire | CPU: ★★★☆☆ | MEM: ★★★★☆
    #Filter_DirectionalBoxBlur          ; Box blur orienté | CPU: ★★★★☆ | MEM: ★★★★☆
    #Filter_RadialBlur                  ; Flou radial linéaire | CPU: ★★★☆☆ | MEM: ★★★★☆
    #Filter_RadialBlur_IIR              ; Flou radial exponentiel | CPU: ★★★★☆ | MEM: ★★★★☆
    #Filter_ZoomBlur                    ; Flou de zoom vers un point | CPU: ★★★☆☆ | MEM: ★★★★☆
    #Filter_RotationalBlur              ; Flou de rotation | CPU: ★★★☆☆ | MEM: ★★★★☆
    #Filter_SpinBlur                    ; Rotation pure | CPU: ★★★☆☆ | MEM: ★★★★☆
    #Filter_SpiralBlur_IIR              ; Flou en spirale exponentiel | CPU: ★★★☆☆ | MEM: ★★★★☆
    #Filter_Spiral_Stochastic           ; Spirale stochastique | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_Spiral_Accumulation         ; Spirale par accumulation | CPU: ★★★☆☆ | MEM: ★★★☆☆
    #Filter_Spiral_Separable            ; Spirale séparable | CPU: ★★★☆☆ | MEM: ★★★★☆
    #Filter_TwistBlur                   ; Flou de torsion | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_CameraShakeBlur             ; Tremblement caméra | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    
    ; ─── Blur_EdgeAware ───
    #Filter_Bilateral                   ; Bilatéral (préserve contours) | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_Edge_Aware                  ; Dépendant des gradients | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_GuidedFilterColor           ; Flou guidé par image | CPU: ★★★☆☆ | MEM: ★★★☆☆
    #Filter_WLSBlur                     ; Moindres carrés pondérés | CPU: ★★☆☆☆ | MEM: ★★☆☆☆
    #Filter_DomainTransform             ; Edge-aware rapide | CPU: ★★★☆☆ | MEM: ★★★☆☆
    #Filter_MultiScaleBilateralBlur     ; Bilatéral multi-échelle | CPU: ★★☆☆☆ | MEM: ★★☆☆☆
    #Filter_BilateralLaplacianBlur      ; Bilatéral + Laplacien | CPU: ★★☆☆☆ | MEM: ★★☆☆☆
    #Filter_SmartBlur                   ; Flou intelligent avec seuils | CPU: ★★★☆☆ | MEM: ★★★☆☆
    #Filter_SurfaceBlur                 ; Flou de surface | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    
    ; ─── Blur_Adaptive ───
    #Filter_MedianBlur                  ; Filtre médian | CPU: ★★★☆☆ | MEM: ★★★★☆
    #Filter_AnisotropicBlur             ; Diffusion anisotrope | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_KuwaharaBlur                ; Variance locale (Kuwahara) | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_NLMBlur                     ; Non-Local Means | CPU: ★☆☆☆☆ | MEM: ★☆☆☆☆
    #Filter_RollingGuidanceFilter       ; Filtrage guidé itératif | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    
    ; ─── Blur_Stochastic ───
    #Filter_PoissonDiskBlur             ; Échantillonnage Poisson | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_StochasticBlur              ; Échantillonnage aléatoire | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_MonteCarloBlur              ; Intégration Monte Carlo | CPU: ★☆☆☆☆ | MEM: ★★☆☆☆
    #Filter_FrostedGlassBlur            ; Verre dépoli (jitter) | CPU: ★★★☆☆ | MEM: ★★★★☆
    
    ; ─── Blur_Optical ───
    #Filter_OpticalBlur                 ; PSF optique | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_BokehBlur                   ; Bokeh circulaire | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_PolygonBokehBlur            ; Bokeh polygonal | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_CatEyeBokehBlur             ; Bokeh œil de chat | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_ChromaticBokehBlur          ; Bokeh chromatique | CPU: ★☆☆☆☆ | MEM: ★★☆☆☆
    #Filter_AdvancedChromaticBokehBlur  ; Bokeh chromatique avancé | CPU: ★☆☆☆☆ | MEM: ★☆☆☆☆
    #Filter_DepthAwareBlur              ; DOF dépendant profondeur | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_DefocusBlur                 ; Défocalisation simulée | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_LensBlur                    ; Aberrations optiques réalistes | CPU: ★☆☆☆☆ | MEM: ★★☆☆☆
    
    ; ─── Blur_MultiScale ───
    #Filter_LaplacianPyramidBlur        ; Pyramide laplacienne | CPU: ★★★☆☆ | MEM: ★★☆☆☆
    #Filter_GaussianPyramidBlur         ; Pyramide gaussienne | CPU: ★★★☆☆ | MEM: ★★☆☆☆
    #Filter_HDRBloomLaplace             ; Bloom HDR Laplacien | CPU: ★★★☆☆ | MEM: ★★☆☆☆
    
    ; ─── Blur_Morphological ───
    #Filter_MorphBlur                   ; Flou morphologique (min+max)/2 | CPU: ★★★☆☆ | MEM: ★★★★☆
    #Filter_MorphOpenCloseBlur          ; Ouverture/fermeture morphologique | CPU: ★★★☆☆ | MEM: ★★★★☆
    #Filter_ErosionBlur                 ; Érosion morphologique (min) | CPU: ★★★☆☆ | MEM: ★★★★☆
    #Filter_DilationBlur                ; Dilatation morphologique (max) | CPU: ★★★☆☆ | MEM: ★★★★☆
    #Filter_BalancedMorphBlur           ; Morphologique équilibré | CPU: ★★★☆☆ | MEM: ★★★★☆
    
    ; ─── Blur_Artistic ───
    #Filter_OilPaintBlur                ; Effet peinture à l'huile | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_WatercolorBlur              ; Effet aquarelle | CPU: ★★☆☆☆ | MEM: ★★☆☆☆
    #Filter_TiltShift                   ; Effet miniature | CPU: ★★★☆☆ | MEM: ★★★☆☆
    #Filter_IrisBlur                    ; Flou iris circulaire graduel | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_PastelBlur                  ; Effet pastel | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_CharcoalBlur                ; Fusain | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_InkBlur                     ; Encre/aquarelle | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    #Filter_DreamGlow                   ; Glow rêveur | CPU: ★★☆☆☆ | MEM: ★★★☆☆
    
    ; ─── Blur_Specialized ───
    #Filter_UnsharpMask                 ; Masque flou (accentuation) | CPU: ★★★☆☆ | MEM: ★★★☆☆
    #Filter_SharpenBlur                 ; Flou + netteté combinés | CPU: ★★★☆☆ | MEM: ★★★☆☆
    #Filter_LowPassBlur                 ; Passe-bas fréquentiel | CPU: ★★☆☆☆ | MEM: ★★☆☆☆
    
    ; ─── Blur_Advanced ───
    #Filter_PermutohedralLattice        ; Filtrage haute dimension | CPU: ★★★☆☆ | MEM: ★★☆☆☆
    
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ EDGE DETECTION FILTERS
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    
    ; ─── EdgeDetect_Gradient (dérivées premières) ───
    #Filter_Roberts                     ; Opérateur Roberts (2×2)
    #Filter_Prewitt                     ; Opérateur Prewitt (3×3)
    #Filter_Sobel                       ; Opérateur Sobel (3×3)
    #Filter_Sobel_4D                    ; Sobel 4 directions
    #Filter_Scharr                      ; Opérateur Scharr (3×3, précis)
    #Filter_Scharr_4D                   ; Scharr 4 directions
    #Filter_Kirsch                      ; Opérateur Kirsch (8 directions)
    #Filter_Robinson                    ; Opérateur Robinson
    #Filter_FreiChen                    ; Opérateur Frei-Chen
    #Filter_Kayyali                     ; Opérateur Kayyali
    #Filter_NevatiaBabu                 ; Opérateur Nevatia-Babu
    #Filter_DerivativeOfGaussian        ; Dérivée de gaussienne
    
    ; ─── EdgeDetect_Laplacian (dérivées secondes) ───
    #Filter_Laplacian                   ; Laplacien simple
    #Filter_LaplacianOfGaussian         ; LoG (Laplacien de gaussienne)
    #Filter_DoG                         ; DoG (Différence de gaussiennes)
    #Filter_MarrHildreth                ; Marr-Hildreth
    #Filter_MexicanHat                  ; Mexican Hat (chapeau mexicain)
    #Filter_ZeroCrossing                ; Détection de passages par zéro
    
    ; ─── EdgeDetect_Advanced ───
    #Filter_Canny                       ; Canny (multi-étapes optimal)
    #Filter_CannyDeriche                ; Canny-Deriche (récursif)
    #Filter_PhaseCongruency             ; Congruence de phase
    #Filter_Gabor                       ; Filtres de Gabor
    #Filter_Steerable                   ; Filtres orientables
    #Filter_StructuredEdgeDetection     ; Détection structurée (apprentissage)
    #Filter_HED                         ; HED (Holistically-nested Edge Detection)
    
    ; ─── EdgeDetect_Morphological ───
    #Filter_MorphologicalGradient       ; Gradient morphologique
    #Filter_BeucherGradient             ; Gradient de Beucher
    #Filter_TopHatEdge                  ; Top-hat pour contours
    
    ; ─── EdgeDetect_MultiScale ───
    #Filter_LaplacianPyramidSharpen     ; Accentuation par pyramide laplacienne
    #Filter_MultiscaleEdge              ; Détection multi-échelle
    #Filter_WaveletEdge                 ; Contours par ondelettes
    
    ; ─── EdgeDetect_Specialized ───
    #Filter_ColorEdgeDetection          ; Détection sur couleurs
    #Filter_TextureEdge                 ; Contours de texture
    #Filter_SubpixelEdge                ; Détection sous-pixel
    #Filter_OrientedEdge                ; Contours orientés
    
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ DITHERING FILTERS
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    
    ; ─── Dither_ErrorDiffusion ───
    #Filter_FloydDither                 ; Floyd-Steinberg (classique, 1976)
    #Filter_FalseFloydSteinberg         ; Version simplifiée 3×1
    #Filter_JJNDither                   ; Jarvis-Judice-Ninke (large diffusion)
    #Filter_StuckiDither                ; Stucki (diffusion étendue)
    #Filter_StevensonArce               ; Diffusion 4 lignes (haute qualité)
    #Filter_BurkesDither                ; Burkes (diffusion moyenne)
    #Filter_SierraDither                ; Sierra (3 lignes)
    #Filter_SierraTwoRow                ; Sierra Two Row (2 lignes)
    #Filter_SierraLiteDither            ; Sierra Lite (rapide)
    #Filter_AtkinsonDither              ; Atkinson (style Mac, partiel)
    #Filter_ShiauFanDither              ; Shiau-Fan (variante asiatique)
    #Filter_MinAvgErr                   ; Minimized Average Error
    
    ; ─── Dither_Ordered ───
    #Filter_Bayer2x2Dither              ; Matrice 2×2 (minimale)
    #Filter_Bayer4x4Dither              ; Matrice 4×4 (standard)
    #Filter_Bayer8x8Dither              ; Matrice 8×8 (détails fins)
    #Filter_ClusteredDot                ; Points groupés (imprimerie)
    #Filter_DispersedDot                ; Points dispersés
    #Filter_HalftoneScreen              ; Trame de demi-teintes
    #Filter_ThresholdMatrix             ; Matrices de seuil personnalisées
    
    ; ─── Dither_Random ───
    #Filter_RandomDither                ; Bruit blanc pur
    
    ; ─── Dither_Stochastic ───
    #Filter_BlueNoiseDither             ; Bruit bleu (distribution optimale)
    #Filter_GreenNoiseDither            ; Compromis blue/ordered
    #Filter_VoidAndCluster              ; Void-and-cluster (sophistiqué)
    
    ; ─── Dither_Adaptive ───
    #Filter_AdaptiveDither              ; Adaptatif au contenu
    #Filter_VariableErrorDiffusion      ; Coefficients variables
    
    ; ─── Dither_Hybrid ───
    #Filter_RiemersmaHilbert            ; Courbe de Hilbert
    #Filter_RiemersmaError              ; Riemersma simplifié
    #Filter_KiteDither                  ; Méthode hybride
    
    ; ─── Dither_Fast (optimisations) ───
    #Filter_LiteDither                  ; Diffusion 1 pixel (ultra-rapide)
    
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ COLOR ADJUSTMENT FILTERS
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    
    ; ─── ColorAdjust_Basic ───
    #Filter_Brightness                  ; Luminosité
    #Filter_Contrast                    ; Contraste
    #Filter_Saturation                  ; Saturation
    #Filter_Gamma                       ; Correction gamma
    
    ; ─── ColorAdjust_Advanced ───
    #Filter_Balance                     ; Balance des blancs
    #Filter_Exposure                    ; Exposition
    #Filter_Normalize_Color             ; Normalisation couleur
    #Filter_AutoOtsuThreshold           ; Seuillage auto Otsu
    
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ COLOR EFFECTS FILTERS
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    
    ; ─── ColorEffect_Mono ───
    #Filter_Grayscale                   ; RGB → Gris (plusieurs méthodes)
    #Filter_BlackAndWhite               ; Seuillage binaire N&B
    
    ; ─── ColorEffect_Toning ───
    #Filter_Sepia                       ; Teinte sépia vintage
    #Filter_Colorize                    ; Mélange couleur/gris (0-512)
    #Filter_HueRotation                 ; Rotation de teinte
    
    ; ─── ColorEffect_Manipulation ───
    #Filter_Negatif                     ; Inversion RGB
    #Filter_Posterize                   ; Réduction de niveaux
    #Filter_VibrantColors               ; Renforcement saturation
    #Filter_FalseColor                  ; LUT couleur par intensité
    #Filter_Dichromatic                 ; Binarisation couleur
    #Filter_PencilSketch                ; Effet crayon graphite
    #Filter_SquareLawLightening         ; Éclaircissement √
    
    ; ─── ColorEffect_Selective ───
    #Filter_HueReplace                  ; Remplacer teinte A → B
    #Filter_SelectiveDesaturation       ; Désaturation sélective
    #Filter_ChannelMix                  ; Mélange créatif canaux
    #Filter_ChannelSwap                 ; Permutation canaux
    #Filter_SelectiveColor              ; Conditions complexes canaux
    #Filter_Hollow                      ; Effet Hollow (à documenter)
    #Filter_Bend                        ; Effet Bend (à reclasser?)
    
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ ARTISTIC FILTERS
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    
    ; ─── Artistic_Light ───
    #Filter_GlowEffect_IIR              ; Effet glow récursif
    #Filter_Fake_HDR                    ; Simulation HDR
    #Filter_dragan
    #Filter_hdr_artistic
    
    ; ─── Artistic_Material ───
    #Filter_Pencil                      ; Effet crayon
    #Filter_CharcoalImage               ; Effet fusain
    #Filter_watercolor
    #Filter_gouache
    #Filter_pastel
    #Filter_impasto
    #Filter_sketch
    
    ; ─── Artistic_Other ───
    #Filter_Emboss                      ; Embossage avec lumière déplaçable
    #Filter_RaysFilter                  ; Rayons lumineux
    #Filter_Histogram                   ; Visualisation histogramme
    #Filter_Fractalius
    #Filter_cartoon
    
    #Filter_crosshatching
    #Filter_BrushedMetal
    
    #Filter_FlowPaint
    
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ TEXTURE & PATTERN FILTERS
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    
    ; ─── Texture_Mosaic ───
    #Filter_Mosaic                      ; Mosaïque rectangulaire
    #Filter_HexMosaic                   ; Mosaïque hexagonale régulière
    #Filter_IrregularHexMosaic          ; Mosaïque hexagonale irrégulière
    
    ; ─── Texture_Detail ───
    #Filter_Diffuse                     ; Diffusion de pixels
    #Filter_Glitch                      ; Effet glitch
    #Filter_Kaleidoscope                ; Effet kaléidoscope
    #Filter_Metallic_Effect             ; Effet métallique
    
    ; ─── Texture_Relief ───
    #Filter_Emboss_Bump                 ; Embossage bump mapping
    #Filter_Mettalic
    
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ TEXTURE 
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    #Filter_texture_synthesis
    
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ DEFORMATION FILTERS
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    
    ; ─── Deform_Basic ───
    #Filter_FlipH                       ; Miroir horizontal
    #Filter_FlipV                       ; Miroir vertical
    #Filter_Rotate                      ; Rotation
    #Filter_Translate                   ; Translation
    #Filter_Mirror                      ; Symétrie axiale configurable
    #Filter_Shear                       ; Cisaillement (parallélogramme)
    
    ; ─── Deform_Projection ───
    #Filter_PerspectiveSimple           ; Perspective simplifiée
    #Filter_Perspective                 ; Perspective standard
    #Filter_Perspective2                ; Perspective alternative
    #Filter_PerspectiveHomography       ; Perspective par homographie
    #Filter_CylindricalProjection       ; Projection cylindrique
    #Filter_SphericalProjection         ; Projection sphérique
    
    ; ─── Deform_Radial ───
    #Filter_Spherize                    ; Sphérisation
    #Filter_Ellipse                     ; Ellipse/sphéroïde
    #Filter_PinchBulge                  ; Pincement/gonflement
    #Filter_Lens                        ; Déformation lentille
    #Filter_Fish_Eye                    ; Effet fish-eye (ultra grand-angle)
    #Filter_Barrel                      ; Distorsion barillet/coussinet
    #Filter_Polar_Transform             ; Transformation polaire ↔ cartésienne
    
    ; ─── Deform_Wave ───
    #Filter_Ripple                      ; Ondulation radiale
    #Filter_Wave                        ; Ondulation linéaire (sin)
    #Filter_WaveCircular                ; Vague circulaire
    #Filter_Zigzag                      ; Ondulation en zigzag
    
    ; ─── Deform_Advanced ───
    #Filter_Spiralize                   ; Spirale
    #Filter_Twirl                       ; Tourbillon/vortex
    #Filter_Tile                        ; Pavage/répétition
    #Filter_Deform_Bend                 ; Courbure
    #Filter_FlowLiquify                 ; Liquéfaction
    #Filter_DisplacementMap             ; Carte de déplacement
    #Filter_DisplacementMap2
    #Filter_Dilate                      ; Dilatation spatiale
    #Filter_Kaleidoscope2               ; Kaléidoscope radial (N secteurs)
    #Filter_Glass                       ; Verre dépoli (déplacement aléatoire)
    #Filter_Squeeze                     ; Compression/étirement
    #Filter_MeshWarp                    ; Déformation par grille de contrôle
    #Filter_Liquify                     ; Liquéfaction interactive
    
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ CONVOLUTION FILTERS
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    
    ; ─── Convolution_Custom ───
    #Filter_Convolution3x3              ; Matrice 3×3 personnalisée
    #Filter_Convolution5x5              ; Matrice 5×5 personnalisée
    #Filter_Convolution7x7
    
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ COLOR SPACE CONVERSION FILTERS
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    
    ; ─── ColorSpace_YUV ───
    #Filter_RgbToYuv                    ; RGB → YUV
    #Filter_YUVtoRGB                    ; YUV → RGB
    
    ; ─── ColorSpace_YIQ ───
    #Filter_RGBtoYIQ                    ; RGB → YIQ
    #Filter_YIQtoRGB                    ; YIQ → RGB
    
    ; ─── ColorSpace_LAB ───
    #Filter_RGBtoLAB                    ; RGB → LAB
    #Filter_LABtoRGB
    
    ; ─── ColorSpace_Other ───
    #Filter_RGBtoHSV                
    #Filter_HSVtoRGB                  
    #Filter_RGBtoHSL                  
    #Filter_HSLtoRGB
    #Filter_RGBtoHUE
    #Filter_HUEtoRGB
    
    #Filter_RGBtoCMYK
    #Filter_CMYKtoRGB
    #Filter_LABtoLCH
    #Filter_LCHtoLAB
    #Filter_RGBtoXYZ
    #Filter_XYZtoRGB
    #Filter_RGBtoYCbCr
    #Filter_YCbCrtoRGB
    
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ BLEND MODE FILTERS
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    
    ; ─── Blend_Additive ───
    #Filter_Blend_Additive              ; Addition simple
    #Filter_Blend_Additive_Inverted     ; Addition inversée
    #Filter_Blend_AlphaBlend            ; Mélange alpha
    #Filter_Blend_Average               ; Moyenne
    #Filter_Blend_LightBlend            ; Mélange léger
    #Filter_Blend_IntensityBoost        ; Boost d'intensité
    #Filter_Blend_BrushUp               ; Brush up
    #Filter_Blend_Lighten               ; Éclaircir
    #Filter_Blend_Screen                ; Screen (écran)
    #Filter_Blend_LinearLight           ; Lumière linéaire
    #Filter_Blend_SoftAdd               ; Addition douce
    
    ; ─── Blend_Subtractive ───
    #Filter_Blend_Burn                  ; Brûlure
    #Filter_Blend_SubtractiveDodge      ; Dodge soustractif
    #Filter_Blend_ColorBurn             ; Brûlure couleur
    #Filter_Blend_ColorDodge            ; Dodge couleur
    #Filter_Blend_InvBurn               ; Brûlure inverse
    #Filter_Blend_InvColorBurn          ; Brûlure couleur inverse
    #Filter_Blend_InvColorDodge         ; Dodge couleur inverse
    #Filter_Blend_InvDodge              ; Dodge inverse
    #Filter_Blend_LinearBurn            ; Brûlure linéaire
    #Filter_Blend_Subtractive           ; Soustractif
    #Filter_Blend_SubtractiveBlend      ; Mélange soustractif
    #Filter_Blend_SoftColorBurn         ; Brûlure couleur douce
    #Filter_Blend_SoftColorDodge        ; Dodge couleur doux
    
    ; ─── Blend_Multiply ───
    #Filter_Blend_Multiply              ; Multiplication
    #Filter_Blend_InverseMultiply       ; Multiplication inverse
    #Filter_Blend_Darken                ; Assombrir
    #Filter_Blend_Difference            ; Différence
    #Filter_Blend_Div                   ; Division
    #Filter_Blend_Exponentiale          ; Exponentielle
    #Filter_Blend_Negation              ; Négation
    
    ; ─── Blend_Contrast ───
    #Filter_Blend_Contrast              ; Contraste
    #Filter_Blend_Cosine                ; Cosinus
    #Filter_Blend_CrossFading           ; Fondu enchaîné
    #Filter_Blend_HardContrast          ; Contraste dur
    #Filter_Blend_CosBlend              ; Mélange cosinus
    
    ; ─── Blend_Soft ───
    #Filter_Blend_SoftLight             ; Lumière douce
    #Filter_Blend_SoftLightBoost        ; Boost lumière douce
    #Filter_Blend_SoftOverlay           ; Superposition douce
    #Filter_Blend_Pegtop_Soft_Light     ; Lumière douce Pegtop
    #Filter_Blend_Interpolation         ; Interpolation
    #Filter_Blend_Mean                  ; Moyenne
    #Filter_Blend_ColorVivify           ; Vivification couleur
    
    ; ─── Blend_Hard ───
    #Filter_Blend_Hardlight             ; Lumière dure
    #Filter_Blend_TanBlend              ; Mélange tangente
    #Filter_Blend_HardTangent           ; Tangente dure
    #Filter_Blend_Heat                  ; Chaleur
    #Filter_Blend_InHale                ; Inhalation
    #Filter_Blend_Intensify             ; Intensification
    #Filter_Blend_PinLight              ; Pin light
    #Filter_Blend_Stamp                 ; Tampon
    
    ; ─── Blend_Other ───
    #Filter_Blend_And                   ; ET logique
    #Filter_Blend_Or                    ; OU logique
    #Filter_Blend_Xor                   ; XOR logique
    #Filter_Blend_Overlay               ; Superposition
    #Filter_Blend_Quadritic             ; Quadratique
    #Filter_Blend_RMSColor              ; RMS couleur
    #Filter_Blend_Fade                  ; Fondu
    #Filter_Blend_Fence                 ; Fence
    #Filter_Blend_Freeze                ; Gel
    #Filter_Blend_Glow                  ; Luminescence
    #Filter_Blend_Logarithmic           ; Logarithmique
    
     
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ RESIZE
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    #Filter_2xSaIEx
    #Filter_ResizeAdvMAME2x
    #Filter_ResizeBell
    #Filter_ResizeBicubic
    #Filter_ResizeBilinear
    #Filter_ResizeEPX
    #Filter_ResizeHermite
    #Filter_ResizeHq2x
    #Filter_ResizeHq3x
    #Filter_ResizeHq4x
    #Filter_ResizeLanczos
    #Filter_ResizeMitchell
    #Filter_ResizeNearest
    #Filter_ResizeScale2x
    #Filter_ResizeSuperEagle
    #Filter_ResizeXBRZ2x
    #Filter_ResizeXBRZ3
    #Filter_ResizeXBRZ4
    #Filter_ResizeXBRZ5
    #Filter_ResizeXBRZ6Ex
    #Filter_SeamCarving_Energy
    
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ OTHER / MISC FILTERS
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    
    #Filter_other_fire
    ;#FilterType_Other
    
  EndEnumeration
  
  
  ;}
  
  ;-- structure
  Structure FilterParams
    image.i[4] ; 0 = source , 1 = cible , 2 = mix , 3 = mask
    addr.i[32] ; adresse temporaire utiliser en interne
    image_lg.l[4]
    image_ht.l[4]
    option.f[32]
    
    info_active.l ; =0  applique le filtre : =1 retourne les infos du filtre sans appliquer le filtre
    mask_type.l   ; definis le type de mask , =0 pas de masque : =1 masque binaire (0 ou 1) : =2 mix le masque (alpha)
    source_mask.i ; buffer source1 (utile si plusieurs filtres utilisés d'affilée)
    tempo.i       ; buffer temporaire pour ne pas modifier la source (utile si plusieurs filtres utilisés d'affilée)
    
    thread.l
    thread_max.l         ; nombre total de threads 
    thread_pos.l         ; position du thread courant
    
    asm.l
    asm_max.l ; language maximum supporter
    
    StructureUnion
      convol3.l[9] ; (3 * 3) 
      convol5.l[25] ; (5 * 5)
      convol7.l[49] ; (7 * 7)
    EndStructureUnion
    
    typ.l
    SubType.l
    name.s
    remarque.s
    info.s[20] 
    Array info_data.l(20,2)
  EndStructure
  Global FilterCtx.FilterParams
  Global.FilterParams Dim dim_FilterParams(128) ; 128 thread max
  
  Global Dim tabfunc.i(999)
  Global optimisation_asm
  
  Macro DeclareModule_filtresadd_function(MaFunction , pos = 0)
    If pos > -1
      Declare MaFunction(*p)
      tabfunc(pos) = @MaFunction()
    EndIf
  EndMacro
  
  Declare Clear_Data_Filter(*param)
  Declare Load_Image_32(n,t$)
  
  Declare Set_SourceEx(adresse_memoire_image , lg , ht)
  Declare Set_CibleEX(adresse_memoire_image , lg , ht)
  Declare Set_MixEX(adresse_memoire_image , lg , ht)
  Declare Set_MaskEX(adresse_memoire_image , lg , ht)
  
  Declare Set_Source(image)
  Declare Set_Cible(image)
  Declare Set_Mix(image)
  Declare Set_Mask(image)
  
  Declare Set_thread(nb_de_thread)
  Declare Set_language(langue)
  Declare get_language()
  Declare get_language_max()
  
  Declare DetectCPU()
  
  ;--
  ;-- decalartion des fonctions
  ;--
  ;-- DeclareModule Blur
  ;#Blur_Classic
  DeclareModule_filtresadd_function(BoxBlurEx , #Filter_BoxBlur)
  Declare BoxBlur(source , cible , mask , rx , ry , nombre_de_passe = 1 , bord = 0)
  DeclareModule_filtresadd_function(GuillossienEx , #Filter_Guillossien)
  Declare Guillossien(source , cible , mask , rx , ry , ndp = 1, bord = 0)
  DeclareModule_filtresadd_function(SummedAreaEx ,  #Filter_SummedArea)
  Declare SummedArea(source , cible , mask , rayon)
  DeclareModule_filtresadd_function(Blur_IIREx , #Filter_Blur_IIR)
  Declare Blur_IIR(source , cible , mask , rx , ry , ndp = 1)
  DeclareModule_filtresadd_function(StackBlurEx , #Filter_StackBlur)
  Declare StackBlur(source , cible , mask , rx , ry , ndp = 1)
  DeclareModule_filtresadd_function(CircularMeanblurEx , #filter_CircularMeanblur)
  Declare CircularMeanblur(source , cible , mask , rayon)
  
  ;CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  ;#Blur_Directional
  DeclareModule_filtresadd_function(RadialBlurEx , #Filter_RadialBlur)
  Declare RadialBlur(source , cible , mask , echantillonnage , posx , posy , rmax)
  DeclareModule_filtresadd_function(RadialBlur_IIREx , #Filter_RadialBlur_IIR)
  Declare RadialBlur_IIR(source , cible , mask , Rayon , posx , posy , qualite)
  DeclareModule_filtresadd_function(SpiralBlur_IIREx , #Filter_SpiralBlur_IIR)
  Declare SpiralBlur_IIR(source , cible , mask , rayon , posx , posy , force , qualite , ra , sens)
  DeclareModule_filtresadd_function(spiral_stochasticEx , #Filter_spiral_stochastic)
  Declare spiral_stochastic(source , cible , mask , rayon , posx , posy , force , qualite , ra , sens)
  DeclareModule_filtresadd_function(spiral_AccumulationEx , #Filter_spiral_Accumulation)
  Declare spiral_Accumulation(source , cible , mask , rayon , posx , posy , force , qualite , ra , sens)
  DeclareModule_filtresadd_function(spiral_SeparableEx , #Filter_spiral_Separable)
  Declare spiral_Separable(source , cible , mask , rayon , posx , posy , force , qualite , ra , sens)
  DeclareModule_filtresadd_function(DirectionalBoxBlurEx , #Filter_DirectionalBoxBlur)
  Declare DirectionalBoxBlur(source , cible , mask , angle , radius , ndp)
  DeclareModule_filtresadd_function(MotionBlurEx , #Filter_MotionBlur)
  Declare MotionBlur(source , cible , mask , rayon , angle)
  DeclareModule_filtresadd_function(ZoomBlurEx , #Filter_ZoomBlur)
  Declare ZoomBlur(source , cible , mask , Force , echantillons , cx , cy )
  DeclareModule_filtresadd_function(RotationalBlurEx , #Filter_RotationalBlur)
  Declare RotationalBlur(source , cible , mask , cx , cy , angle , echantillons)
  DeclareModule_filtresadd_function(TwistBlurEx , #Filter_TwistBlur)
  Declare TwistBlur(source, cible, mask, cx, cy, angle, rayon, echantillons)
  DeclareModule_filtresadd_function(CameraShakeBlurEx , #Filter_CameraShakeBlur)
  Declare CameraShakeBlur(source, cible, mask, samples, intensite, pattern, attenuation, seed)
  DeclareModule_filtresadd_function(SpinBlurEx , #Filter_SpinBlur)
  Declare SpinBlur(source, cible, mask, samples, angle, cx, cy, attenuation, ponderation)
  ;#Blur_Gaussian
  DeclareModule_filtresadd_function(GaussianBlur_ConvEx , #Filter_GaussianBlur_Conv)
  Declare GaussianBlur_Conv(source, cible, mask, rayon)
  DeclareModule_filtresadd_function(SeparableGaussianEx , #Filter_SeparableGaussian)
  Declare SeparableGaussian(source, cible, mask, rayon, sigma_x10)
  DeclareModule_filtresadd_function(HeatDiffusionBlurEx , #Filter_HeatDiffusionBlur)
  Declare HeatDiffusionBlur(source, cible, mask, iterations, contraste, lambda_percent)
  ;#Blur_EdgeAware
  DeclareModule_filtresadd_function(BilateralEx , #Filter_Bilateral)
  Declare Bilateral(source, cible, mask, pass, sigma_space, sigma_color)
  DeclareModule_filtresadd_function(Edge_AwareEx , #Filter_Edge_Aware)
  Declare Edge_Aware(source, cible, mask, sigma_s, sigma_r, iterations)
  DeclareModule_filtresadd_function(GuidedFilterColorEx , #Filter_GuidedFilterColor)
  Declare GuidedFilterColor(source, cible, mask, radius, epsilon)
  DeclareModule_filtresadd_function(WLSBlurEx , #filter_WLSBlur)
  Declare WLSBlur(source, cible, mask, lambda.f, alpha.f, iterations)
  DeclareModule_filtresadd_function(DomainTransformEx , #filter_DomainTransform)
  Declare DomainTransform(source, cible, mask, sigma_s, sigma_r, iterations, mask_type)
  DeclareModule_filtresadd_function(MultiScaleBilateralBlurEx , #filter_MultiScaleBilateralBlur)
  Declare MultiScaleBilateralBlur(source, cible, mask, levels, radius, sigmaColor, mask_type)
  DeclareModule_filtresadd_function(BilateralLaplacianBlurEx , #filter_BilateralLaplacianBlur)
  Declare BilaterallaplacianBlur(source, cible, mask, levels, radius, sigma, mask_type)
  DeclareModule_filtresadd_function(SmartBlurEx , #Filter_SmartBlur)
  Declare SmartBlur(source, cible, mask, radius, threshold, mask_type)
  DeclareModule_filtresadd_function(SurfaceBlurEx , #Filter_SurfaceBlur)
  Declare SurfaceBlur(source, cible, mask, radius, threshold, mask_type)
  ;#Blur_Adaptive
  DeclareModule_filtresadd_function(MedianBlurEx , #Filter_MedianBlur)
  Declare MedianBlur(source, cible, mask, radius, mask_type)
  DeclareModule_filtresadd_function(AnisotropicBlurEx , #Filter_AnisotropicBlur)
  Declare AnisotropicBlur(source, cible, mask, radius, angle, mask_type)
  DeclareModule_filtresadd_function(KuwaharaBlurEx , #Filter_KuwaharaBlur)
  Declare KuwaharaBlur(source, cible, mask, radius, sharpness, iterations, mask_type)
  DeclareModule_filtresadd_function(NLMBlurEx , #filter_NLMBlur)
  Declare NLMBlur(source, cible, mask, searchRadius, patchRadius, hparam, mask_type)
  DeclareModule_filtresadd_function(RollingGuidanceFilterEx , #filter_RollingGuidanceFilter)
  Declare RollingGuidanceFilter(source, cible, mask, radius, sigmaColor, iterations, mask_type)
  ;#Blur_Stochastic
  DeclareModule_filtresadd_function(PoissonDiskBlurEx , #Filter_PoissonDiskBlur)
  Declare PoissonDiskBlur(source, cible, mask, radius, samples, sharpness, iterations, mask_type)
  DeclareModule_filtresadd_function(StochasticBlurEx , #filter_StochasticBlur)
  Declare StochasticBlur(source, cible, mask, radius, samples, mask_type)
  DeclareModule_filtresadd_function(MonteCarloBlurEx , #filter_MonteCarloBlur)
  Declare MonteCarloBlur(source, cible, mask, radius, samples, mask_type)
  DeclareModule_filtresadd_function(FrostedGlassBlurEx , #filter_FrostedGlassBlur)
  Declare FrostedGlassBlur(source, cible, mask, radius, seed, blurRadius)
  ;#Blur_Optical
  DeclareModule_filtresadd_function(OpticalBlurEx , #Filter_OpticalBlur)
  Declare OpticalBlur(source, cible, mask, radius, iterations)
  DeclareModule_filtresadd_function(BokehBlurEx, #filter_BokehBlur)
  Declare BokehBlur(source, cible, mask, radius, sides, highlightBoost)
  DeclareModule_filtresadd_function(PolygonBokehBlurEx , #filter_PolygonBokehBlur)
  Declare PolygonBokehBlur(source, cible, mask, radius, sides, highlightBoost)
  DeclareModule_filtresadd_function(CatEyeBokehBlurEx , #filter_CatEyeBokehBlur)
  Declare CatEyeBokehBlur(source, cible, mask, radius, elongation)
  DeclareModule_filtresadd_function(ChromaticBokehBlurEx , #filter_ChromaticBokehBlur)
  Declare ChromaticBokehBlur(source, cible, mask, radius, chromaShift)
  DeclareModule_filtresadd_function(AdvancedChromaticBokehBlurEx , #filter_AdvancedChromaticBokehBlur)
  Declare AdvancedChromaticBokehBlur(source, cible, mask, radius, sides, chromaShift)
  DeclareModule_filtresadd_function(DepthAwareBlurEx , #Filter_DepthAwareBlur)
  Declare DepthAwareBlur(source, cible, mask, threshold, radius)
  DeclareModule_filtresadd_function(DefocusBlurEx , #Filter_DefocusBlur)
  Declare DefocusBlur(source, cible, mask, radius, samples)
  DeclareModule_filtresadd_function(LensBlurEx , #Filter_LensBlur)
  Declare LensBlur(source, cible, mask, radius, chroma, vignette, samples)
  ;#Blur_MultiScale
  DeclareModule_filtresadd_function(LaplacianPyramidBlurEx , #filter_LaplacianPyramidBlur)
  Declare LaplacianPyramidBlur(source, cible, mask, levels, kernel)
  DeclareModule_filtresadd_function(GaussianPyramidBlurEx , #filter_GaussianPyramidBlur)
  Declare GaussianPyramidBlur(source, cible, mask, radius)
  DeclareModule_filtresadd_function(HDRBloomLaplaceEx , #filter_HDRBloomLaplace)
  Declare HDRBloomLaplace(source, cible, mask, levels, kernel, threshold, intensity)
  ;#Blur_Morphological
  DeclareModule_filtresadd_function(MorphBlurEx , #filter_MorphBlur)
  Declare MorphBlur(source, cible, mask, rayon)
  DeclareModule_filtresadd_function(MorphOpenCloseBlurEx , #filter_MorphOpenCloseBlur)
  Declare MorphOpenCloseBlur(source, cible, mask, rayon)
  DeclareModule_filtresadd_function(ErosionBlurEx , #filter_ErosionBlur)
  Declare ErosionBlur(source, cible, mask, rayon)
  DeclareModule_filtresadd_function(DilationBlurEx , #Filter_DilationBlur)
  Declare DilationBlur(source , cible , mask , rayon)
  DeclareModule_filtresadd_function(BalancedMorphBlurEx , #filter_BalancedMorphBlur)
  Declare BalancedMorphBlur(source, cible, mask, rayon) 
  ;Blur_Artistic
  DeclareModule_filtresadd_function(OilPaintBlurEx , #Filter_OilPaintBlur)
  Declare OilPaintBlur(source, cible, mask, rayon, intensite)
  DeclareModule_filtresadd_function(WatercolorBlurEx , #Filter_WatercolorBlur)
  Declare WatercolorBlur(source, cible, mask, rayon, nettete)
  DeclareModule_filtresadd_function(TiltShiftEx , #Filter_TiltShift)
  Declare TiltShift(source, cible, mask, pos_focus, largeur_focus, rayon, angle)
  DeclareModule_filtresadd_function(IrisBlurEx , #Filter_IrisBlur)
  Declare IrisBlur(source, cible, mask, centreX, centreY, rayon_net, rayon_flou, intensite)
  DeclareModule_filtresadd_function(PastelBlurEx , #Filter_PastelBlur)
  Declare PastelBlur(source, cible, mask, rayon, luminosite, saturation, douceur, contraste)
  DeclareModule_filtresadd_function(CharcoalBlurEx , #Filter_CharcoalBlur)
  Declare CharcoalBlur(source, cible, mask, rayon, intensite, grain, contraste)
  DeclareModule_filtresadd_function(InkBlurEx , #Filter_InkBlur)
  Declare InkBlur(source, cible, mask, rayon, fluidite, densite, etalement)
  DeclareModule_filtresadd_function(DreamGlowEx , #Filter_DreamGlow)
  Declare DreamGlow(source, cible, mask, rayon, intensite, douceur, bloom)
  ;#Blur_Specialized
  DeclareModule_filtresadd_function(UnsharpMaskEx , #Filter_UnsharpMask)
  Declare UnsharpMask(source, cible, mask, rayon, force, seuil)
  DeclareModule_filtresadd_function(SharpenBlurEx , #Filter_SharpenBlur)
  Declare SharpenBlur(source, cible, mask, rayon_flou, force_nettete, ratio_flou)
  DeclareModule_filtresadd_function(LowPassBlurEx , #filter_LowPassBlur)
  Declare LowPassBlur(source, cible, mask, rayon)
  ;#Blur_Advanced
  DeclareModule_filtresadd_function(PermutohedralLatticeEx , #Filter_PermutohedralLattice)
  Declare PermutohedralLattice(source, cible, mask, sigma_spatial, sigma_couleur)
  
  
  ;-- DeclareModule Edge Detection
  ;Filtres basés sur les gradients (dérivées premières)
  DeclareModule_filtresadd_function(RobertsEx , #Filter_Roberts)
  Declare Roberts(source, cible, mask, multiply=10, math=0, gray=0, inverse=0, seuil=0, orient=0, angle=0)
  DeclareModule_filtresadd_function(PrewittEx , #Filter_Prewitt)
  Declare Prewitt(source, cible, mask, multiplicateur=10, noir_blanc=0, inversion=0)
  DeclareModule_filtresadd_function(sobelEx , #Filter_sobel)
  Declare Sobel(source, cible, mask, multiplicateur=10, methode=0, noir_blanc=0, inversion=0)
  DeclareModule_filtresadd_function(sobel_4dEx , #Filter_sobel_4d)
  Declare Sobel_4d(source, cible, mask, multiply=10, math=0, gray=0, inverse=0)
  DeclareModule_filtresadd_function(scharrEx , #Filter_scharr)
  Declare Scharr(source, cible, mask, multiply=10, math=0, gray=0, inverse=0)
  DeclareModule_filtresadd_function(scharr_4dEx , #Filter_scharr_4d)
  Declare Scharr_4d(source, cible, mask, multiply=10, math=0, gray=0, inverse=0)
  DeclareModule_filtresadd_function(kirschEx , #Filter_kirsch)
  Declare Kirsch(source, cible, mask, multiply=10, gray=0, inverse=0)
  DeclareModule_filtresadd_function(robinsonEx , #Filter_robinson)
  Declare Robinson(source, cible, mask, multiply=10, gray=0, inverse=0)
  DeclareModule_filtresadd_function(FreiChenEx , #Filter_FreiChen)
  Declare FreiChen(source, cible, mask, multiply=10, gray=0, inverse=0)
  DeclareModule_filtresadd_function(KayyaliEx , #Filter_Kayyali)
  Declare Kayyali(source, cible, mask, multiply=10, method=1, gray=0, inverse=0)
  DeclareModule_filtresadd_function(NevatiaBabuEx , #Filter_NevatiaBabu)
  Declare NevatiaBabu(source, cible, mask, multiply=10, gray=0, inverse=0)
  DeclareModule_filtresadd_function(DerivativeOfGaussianEx , #Filter_DerivativeOfGaussian)
  Declare DerivativeOfGaussian(source , cible , mask , sigma , multiplicateur , inversion)
  ;Filtres basés sur les dérivées secondes (Laplaciens)
  DeclareModule_filtresadd_function(LaplacianEx , #Filter_Laplacian)
  Declare Laplacian(source , cible , mask , multiply , mode , noir_et_blanc , inversion)
  DeclareModule_filtresadd_function(LaplacianOfGaussianEx , #Filter_LaplacianOfGaussian)
  Declare LaplacianOfGaussian(source , cible , mask , seuil , multiply , maskSize , sigma , inverse , togray)
  DeclareModule_filtresadd_function(DoGEx , #Filter_DoG)
  Declare DoG(source, cible, mask, sigma1, sigma2, math, noir_et_blanc, inversion, seuillage, multiply)
  DeclareModule_filtresadd_function(MarrHildrethEx , #Filter_MarrHildreth)
  Declare MarrHildreth(source , cible , mask , multiplicateur , inversion)
  DeclareModule_filtresadd_function(MexicanHatEx , #Filter_MexicanHat)
  Declare MexicanHat(source, cible, mask, multiplicateur, noir_et_blanc, inversion, sigma)
  DeclareModule_filtresadd_function(ZeroCrossingEx , #Filter_ZeroCrossing)
  Declare ZeroCrossing(source, cible, mask, seuil, type_noyau, noir_et_blanc, inversion)
  ;Méthodes avancées / hybrides
  DeclareModule_filtresadd_function(cannyEx , #Filter_canny)
  Declare Canny(source, cible, mask, sFort, sFaible, brute, hyst)
  DeclareModule_filtresadd_function(CannyDericheEx , #Filter_CannyDeriche)
  Declare CannyDeriche(source, cible, mask, alpha, seuilBas, seuilHaut, nb)
  DeclareModule_filtresadd_function(PhaseCongruencyEx , #Filter_PhaseCongruency)
  Declare PhaseCongruency(source, cible, mask, nscales, norient, minWaveLength, mult, toGray)
  DeclareModule_filtresadd_function(GaborEx , #Filter_Gabor)
  Declare Gabor(source, cible, mask, wavelength, orientation, sigma, gamma, psi, outputMode, toGray, normalize)
  DeclareModule_filtresadd_function(SteerableEx , #Filter_Steerable)
  Declare Steerable(source, cible, mask, multiplicateur, angle, toGray, inverse, mode)
  DeclareModule_filtresadd_function(StructuredEdgeDetectionEx , #Filter_StructuredEdgeDetection)
  Declare StructuredEdgeDetection(source , cible , mask , sensibilite , noyau , gris , inversion , mode)
  DeclareModule_filtresadd_function(hedEx , #Filter_hed)
  Declare HED(source , cible , mask , seuil , echelles , gris , inversion , fusion)
  ;Méthodes morphologiques
  DeclareModule_filtresadd_function(MorphologicalGradientEx , #Filter_MorphologicalGradient)
  Declare MorphologicalGradient(source, cible, mask, force, noyau, gris, inversion, forme)
  DeclareModule_filtresadd_function(BeucherGradientEx , #Filter_BeucherGradient)
  Declare BeucherGradient(source, cible, mask, force, noyau, gris, inversion, forme)
  DeclareModule_filtresadd_function(TopHatEdgeEx , #Filter_TopHatEdge)
  Declare TopHatEdge(source, cible, mask, force, noyau, gris, inversion, mode)
  ;Méthodes multi-échelle
  DeclareModule_filtresadd_function(LaplacianPyramidSharpenEx , #filter_LaplacianPyramidSharpen)
  Declare LaplacianPyramidSharpen(source, cible, mask, niveaux, kernel, gain)
  DeclareModule_filtresadd_function(MultiscaleEdgeEx , #Filter_MultiscaleEdge)
  Declare MultiscaleEdge(source, cible, mask, sensibilite, echelles, nb, inverse, fusion)
  DeclareModule_filtresadd_function(WaveletEdgeEx , #Filter_WaveletEdge)
  Declare WaveletEdge(source, cible, mask, seuil, type, nb, inverse, decomp)
  ;Méthodes spécialisées
  DeclareModule_filtresadd_function(ColorEdgeDetectionEx , #Filter_ColorEdgeDetection)
  Declare ColorEdgeDetection(source, cible, mask, sensibilite, espace, nb, inverse, methode)
  DeclareModule_filtresadd_function(TextureEdgeEx , #Filter_TextureEdge)
  Declare TextureEdge(source, cible, mask, sensibilite, descripteur, nb, inverse, fenetre)
  DeclareModule_filtresadd_function(SubpixelEdgeEx , #Filter_SubpixelEdge)
  Declare SubpixelEdge(source, cible, mask, mul=10, thresh=30, gray=0, inv=0, interp=1, show=0)
  DeclareModule_filtresadd_function(OrientedEdgeEx , #Filter_OrientedEdge)
  Declare OrientedEdge(source , cible , mask , multiply , angle , tolerance , nb , inversion , direction , suppression)
  
  
  ; #Dither_ErrorDiffusion - Diffusion d'erreur classique
  DeclareModule_filtresadd_function(FloydDitherEx , #Filter_FloydDither)
  Declare FloydDither(source , cible , mask , levels , gray)
  DeclareModule_filtresadd_function(FalseFloydSteinbergEx , #Filter_FalseFloydSteinberg)
  Declare FalseFloydSteinberg(source , cible , mask , levels , gray)
  DeclareModule_filtresadd_function(JJNDitherEx , #Filter_JJNDither)
  Declare JJNDither(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(StuckiDitherEx , #Filter_StuckiDither)
  Declare StuckiDither(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(StevensonArceEx , #Filter_StevensonArce)
  Declare StevensonArce(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(BurkesDitherEx , #Filter_BurkesDither)
  Declare BurkesDither(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(SierraDitherEx , #Filter_SierraDither)
  Declare SierraDither(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(SierraTwoRowEx , #Filter_SierraTwoRow)
  Declare SierraTwoRow(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(SierraLiteDitherEx , #Filter_SierraLiteDither)
  Declare SierraLiteDither(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(AtkinsonDitherEx , #Filter_AtkinsonDither)
  Declare AtkinsonDither(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(ShiauFanDitherEx , #Filter_ShiauFanDither)
  Declare ShiauFanDither(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(MinAvgErrEx , #Filter_MinAvgErr)
  Declare MinAvgErr(source, cible, mask, levels, gray)
  ; #Dither_Ordered - Dithering par matrices ordonnées
  DeclareModule_filtresadd_function(Bayer2x2Ex , #Filter_Bayer2x2Dither)
  Declare Bayer2x2(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(Bayer4x4Ex , #Filter_Bayer4x4Dither)
  Declare Bayer4x4(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(Bayer8x8Ex , #Filter_Bayer8x8Dither)
  Declare Bayer8x8(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(ClusteredDotEx , #Filter_ClusteredDot)
  Declare ClusteredDot(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(DispersedDotEx , #Filter_DispersedDot)
  Declare DispersedDot(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(HalftoneScreenEx , #Filter_HalftoneScreen)
  Declare HalftoneScreen(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(ThresholdMatrixEx , #Filter_ThresholdMatrix)
  Declare ThresholdMatrix(source, cible, mask, levels, gray)
  ; #Dither_Random - Bruit aléatoire pur
  DeclareModule_filtresadd_function(RandomDitherEx , #Filter_RandomDither)
  Declare RandomDither(source, cible, mask, levels, gray, intensity)
  ; #Dither_Stochastic - Bruit structuré/optimisé
  DeclareModule_filtresadd_function(BlueNoiseDitherEx , #Filter_BlueNoiseDither)
  Declare BlueNoiseDither(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(GreenNoiseDitherEx , #Filter_GreenNoiseDither)
  Declare GreenNoiseDither(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(VoidAndClusterEx , #Filter_VoidAndCluster)
  Declare VoidAndCluster(source, cible, mask, levels, gray)
  ; #Dither_Adaptive - Méthodes adaptatives au contenu
  DeclareModule_filtresadd_function(AdaptiveDitherEx , #Filter_AdaptiveDither)
  Declare AdaptiveDither(source, cible, mask, levels, gray, sensitivity)
  DeclareModule_filtresadd_function(VariableErrorDiffusionex , #Filter_VariableErrorDiffusion)
  Declare VariableErrorDiffusion(source, cible, mask, levels, gray, algorithm)
  ; #Dither_Hybrid - Méthodes hybrides/space-filling curves
  DeclareModule_filtresadd_function(RiemersmaHilbertEx , #Filter_RiemersmaHilbert)
  Declare RiemersmaHilbert(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(RiemersmaErrorEx , #Filter_RiemersmaError)
  Declare RiemersmaError(source, cible, mask, levels, gray)
  DeclareModule_filtresadd_function(KiteDitherEx , #Filter_KiteDither)
  Declare KiteDither(source, cible, mask, levels, gray)
  ; #Dither_Fast - Optimisations ultra-rapides
  DeclareModule_filtresadd_function(LiteDitherEx , #Filter_LiteDither)
  Declare LiteDither(source, cible, mask, levels, gray)
  
  DeclareModule_filtresadd_function(BalanceEx , #Filter_Balance)
  Declare Balance(source, cible, mask, r_factor, g_factor, b_factor)
  DeclareModule_filtresadd_function(BrightnessEx , #Filter_Brightness)
  Declare Brightness(source, cible, mask, r_adj, g_adj, b_adj)
  DeclareModule_filtresadd_function(ContrastEx , #Filter_Contrast)
  Declare Contrast(source, cible, mask, contrast_factor)
  DeclareModule_filtresadd_function(ExposureEx , #Filter_Exposure)
  Declare Exposure(source, cible, mask, exposure_val)
  DeclareModule_filtresadd_function(GammaEx , #Filter_Gamma)
  Declare Gamma(source, cible, mask, gamma_val)
  DeclareModule_filtresadd_function(Normalize_ColorEx, #Filter_Normalize_Color)
  Declare Normalize_Color(source, cible, mask)
  DeclareModule_filtresadd_function(SaturationEx , #Filter_Saturation)
  Declare Saturation(source, cible, mask, saturation_val)
  DeclareModule_filtresadd_function(AutoOtsuThresholdEX , #Filter_AutoOtsuThreshold)
  Declare AutoOtsuThreshold(source, cible, mask)
  
  ; ═══ Conversion / Base ═══
  DeclareModule_filtresadd_function(grayscaleEx , #Filter_grayscale)
  Declare Grayscale(source, cible, mask, type_gris)
  DeclareModule_filtresadd_function(BlackAndWhiteEx , #Filter_BlackAndWhite)
  Declare BlackAndWhite(source, cible, mask, seuil, mode)
  DeclareModule_filtresadd_function(SepiaEx , #Filter_Sepia)
  Declare Sepia(source, cible, mask, temperature)
  DeclareModule_filtresadd_function(NegatifEx , #Filter_Negatif)
  Declare Negatif(source, cible, mask)
  ; ═══ Saturation ═══
  DeclareModule_filtresadd_function(ColorizeEx , #Filter_Colorize)
  Declare Colorize(source, cible, mask, intensity)
  DeclareModule_filtresadd_function(ReviveColorsEx , #Filter_VibrantColors)
  Declare ReviveColors(source, cible, mask, intensite, mode)
  ; ═══ Teinte ═══
  DeclareModule_filtresadd_function(teinteEx , #Filter_HueRotation)
  Declare Teinte(source, cible, mask, angle, mode)
  DeclareModule_filtresadd_function(ColorPermutationEx , #Filter_HueReplace)
  Declare ColorPermutation(source, cible, mask, target_hue, source_hue, tolerance, show_guides)
  DeclareModule_filtresadd_function(Color_hueEx , #Filter_SelectiveDesaturation)
  Declare Color_hue(source, cible, mask, hue_target, tolerance)
  ; ═══ Quantification ═══
  DeclareModule_filtresadd_function(PosterizeEx , #Filter_Posterize)
  Declare Posterize(source, cible, mask, level_r, level_g, level_b)
  ; ═══ Canaux ═══
  DeclareModule_filtresadd_function(color_effectEx , #Filter_ChannelMix)
  Declare color_effect(source, cible, mask, mode)
  DeclareModule_filtresadd_function(ChannelSwapEx , #Filter_ChannelSwap)
  Declare ChannelSwap(source, cible, mask, mode)
  ; ═══ Effets spéciaux ═══
  DeclareModule_filtresadd_function(FalseColourEx , #Filter_FalseColor)
  Declare FalseColour(source, cible, mask, mode_couleur)
  DeclareModule_filtresadd_function(DichromaticEx , #Filter_Dichromatic)
  Declare Dichromatic(source, cible, mask, intensite)
  DeclareModule_filtresadd_function(PencilImageEx , #Filter_PencilSketch)
  Declare PencilImage(source, cible, mask, intensite, limite, quantification)
  DeclareModule_filtresadd_function(SquareLaw_LighteningEx , #Filter_SquareLawLightening)
  Declare SquareLaw_Lightening(source, cible, mask, intensite)
  ; ═══ Sélectifs ═══
  DeclareModule_filtresadd_function(ColorEx , #Filter_SelectiveColor)
  Declare Color(source, cible, mask, seuil, mode)
  DeclareModule_filtresadd_function(HollowEx , #Filter_Hollow)
  Declare Hollow(source, cible, mask, angle, mode_hollow)
  ; ═══ Divers / Déformation ═══
  DeclareModule_filtresadd_function(BendEx , #Filter_Bend)
  Declare Bend(source, cible, mask, angle_r, angle_g, angle_b)
  
  
  DeclareModule_filtresadd_function(GlowEffect_IIREx , #Filter_GlowEffect_IIR)
  Declare GlowEffect_IIR(source, cible, mask, intensity, radius, threshold)
  DeclareModule_filtresadd_function(FakeHDREx , #Filter_Fake_Hdr)
  Declare FakeHDR(source, cible, mask, vmin, vmax, sh_seuil, sh_val, seuil, glow, strength, radius, contrast, factor, posterize, mix)
  DeclareModule_filtresadd_function(hdr_artisticEx , #Filter_hdr_artistic)
  Declare hdr_artistic(source, cible, mask, strength, tone, halo_r, halo_i, sat, details, equal)
  DeclareModule_filtresadd_function(draganEx , #Filter_dragan)
  Declare dragan(source, cible, mask, intensity, contrast, clarity, desat, skin_prot, grain, vignette)
  
  DeclareModule_filtresadd_function(pencilEx , #Filter_pencil)
  Declare pencil(source, cible, mask, rayon, intensite_melange, gamma, intensite_contours, style)
  DeclareModule_filtresadd_function(CharcoalImageEx , #Filter_CharcoalImage)
  Declare CharcoalImage(source, cible, mask, intensite)
  DeclareModule_filtresadd_function(sketchEx , #Filter_sketch)
  Declare sketch(source, cible, mask, edge=70, density=50, style=2, pencil=40, grain=30, contrast=120)
  DeclareModule_filtresadd_function(watercolorEx , #Filter_watercolor)
  Declare watercolor(source, cible, mask, diffusion=60, radius=4, grain=40, variation=30, edgePreserve=50, satBoost=130)
  DeclareModule_filtresadd_function(gouacheEx , #Filter_gouache)
  Declare gouache(source, cible, mask, brushSize=5, texture=50, matte=70, levels=10, dir=0, contrast=130)
  DeclareModule_filtresadd_function(pastelEx , #Filter_pastel)
  Declare pastel(source, cible, mask, softness=50, grain=60, desat=40, lighten=30, size=3, type=1)
  DeclareModule_filtresadd_function(impastoEx , #Filter_impasto)
  Declare impasto(source, cible, mask, thickness=60, size=7, relief=70, texture=65, direction=0, light=80)
  DeclareModule_filtresadd_function(EmbossEx , #Filter_Emboss)
  Declare emboss(source, cible, mask, hauteur=30, invY=0, boost=0, mode=1, angle=135, elev=45)
  DeclareModule_filtresadd_function(HistogramEx , #Filter_Histogram)
  Declare Histogram(source, cible, mask, intensite=100, modeAuto=0)
  DeclareModule_filtresadd_function(FlowLiquifyEx ,  #Filter_FlowLiquify)
  Declare FlowLiquify(source, cible, mask, intensite=5, echelle=10, mode=0)
  DeclareModule_filtresadd_function(DisplacementMapEx , #Filter_DisplacementMap2)
  Declare DisplacementMap(source, cible, displacement, mask, intensity=50, offX=100, offY=100, wrap=0)
  DeclareModule_filtresadd_function(DilateEx , #Filter_Dilate)
  Declare Dilate(source, cible, mask, taille=0)
  DeclareModule_filtresadd_function(FractaliusEx , #Filter_Fractalius)
  Declare Fractalius(source, cible, mask, intensity=70, edge=80, glow=40, detail=100, sat=120, thresh=20)
  DeclareModule_filtresadd_function(cartoonEx , #Filter_cartoon)
  Declare Cartoon(source, cible, mask, levels=6, edgeSens=50, edgeThick=30, mode=0, color=0, smooth=1)
  DeclareModule_filtresadd_function(crosshatchingEx , #Filter_crosshatching)
  Declare crosshatching(source, cible, mask, strength=100, density=30, thick=15, directions=3, contrast=100, color=0, edges=80)
  
  DeclareModule_filtresadd_function(MetalEffectEx , #Filter_BrushedMetal) 
  Declare MetalEffect(source, cible, mask, brossage=10, rugosite=20, brillance=40)
  
  DeclareModule_filtresadd_function(MosaicEx , #Filter_Mosaic)
  Declare Mosaic(source, cible, mask, pixSize=8)
  DeclareModule_filtresadd_function(HexMosaicEx , #Filter_HexMosaic)
  Declare HexMosaic(source, cible, mask, hexSize=12)
  DeclareModule_filtresadd_function(IrregularHexMosaicEx , #Filter_IrregularHexMosaic)
  Declare IrregularHexMosaic(source, cible, mask, size=12, jitter=50, sides=6, rot=0, alpha=0, edges=0, alpha_edges=0)
  DeclareModule_filtresadd_function(DiffuseEx , #Filter_Diffuse)
  Declare Diffuse(source, cible, mask, intensite=1)
  DeclareModule_filtresadd_function(GlitchEx , #Filter_Glitch)
  Declare Glitch(source, cible, mask, intensity=30, noise=32)
  DeclareModule_filtresadd_function(KaleidoscopeEx , #Filter_Kaleidoscope)
  Declare Kaleidoscope(source, cible, mask, numSlices=6, rotation=360, zoom=100)
  DeclareModule_filtresadd_function(Emboss_bumpEx , #Filter_Emboss_bump)
  Declare Emboss_bump(source, cible, mask, angle=50, inclinaison=25, intensity=250, mix_img=0, mix_alpha=50, bn=0, invert=0)
  
  DeclareModule_filtresadd_function(MetallicEx , #Filter_mettalic)
  Declare Metallic(source, cible, mask, gray , var2 , var3)
  
  DeclareModule_filtresadd_function(FlowPaintEx , #Filter_FlowPaint)
  Declare FlowPaint(source , cible , mask , densite, vit)
  
  DeclareModule_filtresadd_function(FlipHEx , #Filter_FlipH)
  Declare FlipH(source, cible, mask)
  DeclareModule_filtresadd_function(FlipVEx , #Filter_FlipV)
  Declare FlipV(source, cible, mask)
  DeclareModule_filtresadd_function(RotateEx , #Filter_Rotate)
  Declare Rotate(source, cible, mask, angle=0, centreX=50, centreY=50)
  DeclareModule_filtresadd_function(PerspectiveEx , #Filter_Perspective)
  Declare Perspective(source, cible, mask, xHG=50, yHG=50, xHD=50, yHD=50, xBG=50, yBG=50, xBD=50, yBD=50)
  DeclareModule_filtresadd_function(PerspectiveSimpleEx , #Filter_PerspectiveSimple)
  Declare PerspectiveSimple(source, cible, mask, offVG=50, offVD=50, offHH=50, offHB=50)
  DeclareModule_filtresadd_function(TranslateEx , #Filter_Translate)
  Declare Translate(source, cible, mask, offsetX=100, offsetY=100, mode=1)
  DeclareModule_filtresadd_function(SpherizeEx , #Filter_Spherize)
  Declare Spherize(source, cible, mask, force=100, cX=50, cY=50, rayon=50)
  DeclareModule_filtresadd_function(SpiralizeEx , #Filter_Spiralize)
  Declare Spiralize(source, cible, mask, angle=1000, cX=50, cY=50, rayon=50, sens=0)
  DeclareModule_filtresadd_function(EllipzeEx , #Filter_Ellipse)
  Declare Ellipze(source, cible, mask, force=200, cX=50, cY=50, rayonX=50, rayonY=50)
  DeclareModule_filtresadd_function(RippleEx , #Filter_Ripple)
  Declare Ripple(source, cible, mask, ampX=5, perX=10, ampY=5, perY=10)
  DeclareModule_filtresadd_function(PinchBulgeEx , #Filter_PinchBulge)
  Declare PinchBulge(source, cible, mask, force=0, cX=50, cY=50, rayon=30)
  DeclareModule_filtresadd_function(WaveCircularEx , #Filter_WaveCircular)
  Declare WaveCircular(source, cible, mask, amp=10, cX=50, cY=50, wavelength=20, phase=0)
  DeclareModule_filtresadd_function(LensEx , #Filter_Lens)
  Declare Lens(source, cible, mask, zoom=100, cX=50, cY=50, rayon=30)
  DeclareModule_filtresadd_function(TileEx , #Filter_Tile)
  Declare Tile(source, cible, mask, tilesX=10, tilesY=10)
  DeclareModule_filtresadd_function(Perspective2Ex , #Filter_Perspective2)
  Declare Perspective2(source, cible, mask, top=100, bottom=100, left=100, right=100, zoom=100, posX=100, posY=100, rot=0)
  DeclareModule_filtresadd_function(PerspectiveHomographyEx , #Filter_PerspectiveHomography)
  Declare PerspectiveHomography(source, cible, mask, x0=50, y0=50, x1=50, y1=50, x2=50, y2=50, x3=50, y3=50)
  DeclareModule_filtresadd_function(TwirlEx , #Filter_Twirl)
  Declare Twirl(source, cible, mask, angle=1000, posX=50, posY=50, radius=50, falloff=50)
  DeclareModule_filtresadd_function(ShearEx , #Filter_Shear)
  Declare Shear(source, cible, mask, shearX=100, shearY=100, anchorX=50, anchorY=50)
  DeclareModule_filtresadd_function(BarrelEx , #Filter_Barrel)
  Declare Barrel(source, cible, mask, intensity=100, posX=50, posY=50, secondary=0)
  DeclareModule_filtresadd_function(FishEyeEx , #Filter_Fish_Eye)
  Declare FishEye(source, cible, mask, intensity=100, posX=50, posY=50, radius=70, type=0)
  DeclareModule_filtresadd_function(PolarTransformEx , #Filter_Polar_Transform)
  Declare PolarTransform(source, cible, mask, mode=0, posX=50, posY=50, angle=0, wrap=1)
  DeclareModule_filtresadd_function(Kaleidoscope2Ex , #Filter_Kaleidoscope2)
  Declare Kaleidoscope2(source, cible, mask, segments=6, posX=50, posY=50, angle=0, mode=1)
  DeclareModule_filtresadd_function(MirrorEx , #Filter_Mirror)
  Declare Mirror(source, cible, mask, axis=0, pos=50, side=0, fade=0)
  DeclareModule_filtresadd_function(WaveEx , #Filter_Wave)
  Declare Wave(source, cible, mask, amp=10, waveL=50, dir=0, phase=0, type=0)
  DeclareModule_filtresadd_function(ZigzagEx , #Filter_Zigzag)
  Declare Zigzag(source, cible, mask, amp=20, count=10, dir=0, shape=0, smooth=0)
  DeclareModule_filtresadd_function(GlassEx , #Filter_Glass)
  Declare Glass(source, cible, mask, intensity=5, grain=3, mode=0, seed=0)
  DeclareModule_filtresadd_function(SqueezeEx , #Filter_Squeeze)
  Declare Squeeze(source, cible, mask, factX=100, factY=100, cX=50, cY=50, mode=0)
  DeclareModule_filtresadd_function(MeshWarpEx , #Filter_MeshWarp)
  Declare MeshWarp(source, cible, mask, res=5, type=0, intensity=50, interp=1)
  DeclareModule_filtresadd_function(LiquifyEx , #Filter_Liquify)
  Declare Liquify(source, cible, mask, radius=50, intensity=50, posX=50, posY=50, mode=0)
  DeclareModule_filtresadd_function(CylindricalProjectionEx , #Filter_CylindricalProjection)
  Declare CylindricalProjection(source, cible, mask, direction=0, curvature=100, center=50, radius=50, mode=0)
  DeclareModule_filtresadd_function(SphericalProjectionEx , #Filter_SphericalProjection)
  Declare SphericalProjection(source, cible, mask, type=0, posX=50, posY=50, fov=90, rotation=0)
  DeclareModule_filtresadd_function(DisplaceMapEx , #Filter_DisplacementMap)
  Declare DisplaceMap(source, cible, displace_map, mask, intensityX=100, intensityY=100, chanX=0, chanY=1, wrap=1)
  ;;DeclareModule_filtresadd_function(deform_Bend , #Filter_deform_Bend)
  ;DeclareModule_filtresadd_function(texture_synthesis , #Filter_texture_synthesis)
  ;CompilerEndIf
  DeclareModule_filtresadd_function(RGB_To_YUVEx , #Filter_RgbToYuv)
  Declare RGB_To_YUV(source , cible , mask , y , u , v)
  DeclareModule_filtresadd_function(YUVtoRGBex , #Filter_YUVtoRGB)
  Declare YUVtoRGB(source , cible , mask , r , g , b )
  DeclareModule_filtresadd_function(RGBtoYIQex , #Filter_RGBtoYIQ)
  Declare RGBtoYIQ(source, cible, mask, r, g, b)
  DeclareModule_filtresadd_function(YIQtoRGBex , #Filter_YIQtoRGB)
  Declare YIQtoRGB(source, cible, mask, y, i, q)
  DeclareModule_filtresadd_function(RGBtoLABex , #Filter_RGBtoLAB)
  Declare RGB_To_YUV(source , cible , mask , y , u , v)
  DeclareModule_filtresadd_function(LABtoRGBex , #Filter_LABtoRGB)
  Declare LABtoRGB(source , cible , mask , l , a , b)
  DeclareModule_filtresadd_function(RGBtoHSVex , #Filter_RGBtoHSV)
  Declare RGBtoHSV(source, cible, mask, r, g, b)
  DeclareModule_filtresadd_function(HSVtoRGBex , #Filter_HSVtoRGB)
  Declare HSVtoRGB(source, cible, mask, h, s, v) 
  DeclareModule_filtresadd_function(RGBtoHSLex , #Filter_RGBtoHSL)
  Declare RGBtoHSL(source, cible, mask, r, g, b)
  DeclareModule_filtresadd_function(HSLtoRGBex , #Filter_HSLtoRGB)
  Declare HSLtoRGB(source, cible, mask, h, s, l)  
  DeclareModule_filtresadd_function(RGBtoHUEex , #Filter_RGBtoHUE)
  Declare RGBtoHUE(source, cible, mask, hue)
  DeclareModule_filtresadd_function(HUEtoRGBex , #Filter_HUEtoRGB)
  Declare HUEtoRGB(source, cible, mask, hue)     
  DeclareModule_filtresadd_function(RGBtoYCbCrex , #Filter_RGBtoYCbCr)
  Declare RGBtoYCbCr(source, cible, mask, y, cb, cr)
  DeclareModule_filtresadd_function(YCbCrtoRGBex , #Filter_YCbCrtoRGB)
  Declare YCbCrtoRGB(source, cible, mask, y, cb, cr)
  DeclareModule_filtresadd_function(RGBtoCMYKex , #Filter_RGBtoCMYK)
  Declare RGBtoCMYK(source, cible, mask, c, m, y, k)
  DeclareModule_filtresadd_function(CMYKtoRGBex , #Filter_CMYKtoRGB)
  Declare CMYKtoRGB(source, cible, mask, c, m, y, k)
  DeclareModule_filtresadd_function(RGBtoXYZex , #Filter_RGBtoXYZ)
  Declare RGBtoXYZ(source, cible, mask, x, y, z)
  DeclareModule_filtresadd_function(XYZtoRGBex , #Filter_XYZtoRGB)
  Declare XYZtoRGB(source, cible, mask, x, y, z)
  DeclareModule_filtresadd_function(LABtoLCHex , #Filter_LABtoLCH)
  Declare LABtoLCH(source, cible, mask, l, c, h)
  DeclareModule_filtresadd_function(LCHtoLABex , #Filter_LCHtoLAB)
  Declare LCHtoLAB(source, cible, mask, l, c, h)
  
  DeclareModule_filtresadd_function(Convolution3x3Ex,#Filter_Convolution3x3)
  Declare convolution3x3(source , cible , mask , opt = -1)
  Declare convolution3x3_set_Diviseur(opt.f)
  Declare convolution3x3_set_bias(opt.f)
  Declare convolution3x3_set_matrix(opt1.i , opt2.f)
  
  DeclareModule_filtresadd_function(Convolution5x5Ex,#Filter_Convolution5x5)
  Declare convolution5x5(source , cible , mask , opt = -1)
  Declare convolution5x5_set_Diviseur(opt.f)
  Declare convolution5x5_set_bias(opt.f)
  Declare convolution5x5_set_matrix(opt1.i , opt2.f)
  
  DeclareModule_filtresadd_function(Convolution7x7Ex,#Filter_Convolution7x7)
  Declare convolution7x7(source , cible , mask , opt = -1)
  Declare convolution7x7_set_Diviseur(opt.f)
  Declare convolution7x7_set_bias(opt.f)
  Declare convolution7x7_set_matrix(opt1.i , opt2.f)
  
  
  DeclareModule_filtresadd_function(Blend_additiveEx , #Filter_Blend_Additive)
  Declare Blend_additive(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)
  DeclareModule_filtresadd_function(Blend_additive_invertedEx , #Filter_Blend_additive_inverted)
  Declare Blend_additive_inverted(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)
  DeclareModule_filtresadd_function(Blend_alphablendEx , #Filter_Blend_alphablend)
  Declare Blend_alphablend(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) 
  DeclareModule_filtresadd_function(Blend_RMSColorEx , #Filter_Blend_RMSColor)
  Declare Blend_RMSColor(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_AndEx , #Filter_Blend_And)
  Declare Blend_And(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_AverageEx , #Filter_Blend_Average)
  Declare Blend_Average(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) 
  DeclareModule_filtresadd_function(Blend_LightBlendEx , #Filter_Blend_LightBlend)
  Declare Blend_LightBlend(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_IntensityBoostEx , #Filter_Blend_IntensityBoost)
  Declare Blend_IntensityBoost(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_BrushUpEx , #Filter_Blend_BrushUp)
  Declare Blend_BrushUp(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_BurnEx , #Filter_Blend_Burn)
  Declare Blend_Burn(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) 
  DeclareModule_filtresadd_function(Blend_SubtractiveDodgeEx , #Filter_Blend_SubtractiveDodge)
  Declare Blend_SubtractiveDodge(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) 
  DeclareModule_filtresadd_function(Blend_ColorBurnEx , #Filter_Blend_ColorBurn)
  Declare Blend_ColorBurn(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_ColorDodgeEx , #Filter_Blend_ColorDodge)
  Declare Blend_ColorDodge(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_ContrastEx , #Filter_Blend_Contrast)
  Declare Blend_Contrast(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_CosineEx , #Filter_Blend_Cosine)
  Declare Blend_Cosine(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_CrossFadingEx , #Filter_Blend_CrossFading)
  Declare Blend_CrossFading(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_InverseMultiplyEx , #Filter_Blend_InverseMultiply)
  Declare Blend_InverseMultiply(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) 
  DeclareModule_filtresadd_function(Blend_DarkenEx , #Filter_Blend_Darken)
  Declare Blend_Darken(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) 
  DeclareModule_filtresadd_function(Blend_SubtractiveBlendEx , #Filter_Blend_SubtractiveBlend)
  Declare Blend_SubtractiveBlend(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) 
  DeclareModule_filtresadd_function(Blend_DifferenceEx , #Filter_Blend_Difference)
  Declare Blend_Difference(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_DivEx , #Filter_Blend_Div)
  Declare Blend_Div(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_SoftAddEx , #Filter_Blend_SoftAdd)
  Declare Blend_SoftAdd(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_SoftLightBoostEx , #Filter_Blend_SoftLightBoost)
  Declare Blend_SoftLightBoost(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_ExponentialeEx , #Filter_Blend_Exponentiale)
  Declare Blend_Exponentiale(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_FadeEx , #Filter_Blend_Fade)
  Declare Blend_Fade(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_FenceEx , #Filter_Blend_Fence)
  Declare Blend_Fence(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_FreezeEx , #Filter_Blend_Freeze)
  Declare Blend_Freeze(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_GlowEx , #Filter_Blend_Glow)
  Declare Blend_Glow(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_HardContrastEx , #Filter_Blend_HardContrast)
  Declare Blend_HardContrast(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_HardlightEx , #Filter_Blend_Hardlight)
  Declare Blend_Hardlight(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_TanBlendEx , #Filter_Blend_TanBlend)
  Declare Blend_TanBlend(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_HardlTangentEx , #Filter_Blend_HardTangent)
  Declare Blend_HardlTangent(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_HeatEx , #Filter_Blend_Heat)
  Declare Blend_Heat(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_InHaleEx , #Filter_Blend_InHale)
  Declare Blend_InHale(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_IntensifyEx , #Filter_Blend_Intensify)
  Declare Blend_Intensify(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_CosBlendEx , #Filter_Blend_CosBlend)
  Declare Blend_CosBlend(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_InterpolationEx , #Filter_Blend_Interpolation)
  Declare Blend_Interpolation(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_InvBurnEx , #Filter_Blend_InvBurn)
  Declare Blend_InvBurn(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) 
  DeclareModule_filtresadd_function(Blend_InvColorBurnEx , #Filter_Blend_InvColorBurn)
  Declare Blend_InvColorBurn(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_InvColorDodgeEx , #Filter_Blend_InvColorDodge)
  Declare Blend_InvColorDodge(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_InvDodgeEx , #Filter_Blend_InvDodge)
  Declare Blend_InvDodge(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_LightenEx , #Filter_Blend_Lighten)
  Declare Blend_Lighten(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) 
  DeclareModule_filtresadd_function(Blend_LinearBurnEx , #Filter_Blend_LinearBurn)
  Declare Blend_LinearBurn(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) 
  DeclareModule_filtresadd_function(Blend_LinearLightEx , #Filter_Blend_LinearLight)
  Declare Blend_LinearLight(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_LogarithmicEx , #Filter_Blend_Logarithmic)
  Declare Blend_Logarithmic(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_MeanEx , #Filter_Blend_Mean)
  Declare Blend_Mean(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) 
  DeclareModule_filtresadd_function(Blend_ColorVivifyEx , #Filter_Blend_ColorVivify)
  Declare Blend_ColorVivify(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_MultiplyEx , #Filter_Blend_Multiply)
  Declare Blend_Multiply(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_NegationEx , #Filter_Blend_Negation)
  Declare Blend_Negation(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_PinLightEx , #Filter_Blend_PinLight)
  Declare Blend_PinLight(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_OrEx , #Filter_Blend_Or)
  Declare Blend_Or(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)
  DeclareModule_filtresadd_function(Blend_OverlayEx , #Filter_Blend_Overlay)
  Declare Blend_Overlay(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100) 
  DeclareModule_filtresadd_function(Blend_Pegtop_soft_lightEx , #Filter_Blend_Pegtop_soft_light)
  Declare Blend_Pegtop_soft_light(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_quadriticEx , #Filter_Blend_quadritic)
  Declare Blend_quadritic(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_ScreenEx , #Filter_Blend_Screen)
  Declare Blend_Screen(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_SoftColorBurnEx , #Filter_Blend_SoftColorBurn)
  Declare Blend_SoftColorBurn(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_SoftColorDodgeEx , #Filter_Blend_SoftColorDodge)
  Declare Blend_SoftColorDodge(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_SoftLightEx , #Filter_Blend_SoftLight)
  Declare Blend_SoftLight(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_SoftOverlayEx , #Filter_Blend_SoftOverlay)
  Declare Blend_SoftOverlay(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_StampEx , #Filter_Blend_Stamp)
  Declare Blend_Stamp(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_SubtractiveEx , #Filter_Blend_Subtractive)
  Declare Blend_Subtractive(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)  
  DeclareModule_filtresadd_function(Blend_XorEx , #Filter_Blend_Xor)
  Declare Blend_Xor(source , cible , mix , mask , inv1 = 0, inv2 = 0 , scx = 100 , scy = 100, px = 100 , py = 100)
  
  ;DeclareModule_filtresadd_function(fire , #Filter_other_fire)
  
  
  DeclareModule_filtresadd_function(resize2xSaIEx , #Filter_2xSaIEx)
  Declare resize2xSaI(source, cible)
  DeclareModule_filtresadd_function(ResizeAdvMAME2xEx , #Filter_ResizeAdvMAME2x)
  Declare ResizeAdvMAME2x(source, cible)
  
  DeclareModule_filtresadd_function(ResizeHq2xEx , #Filter_ResizeHq2x)
  Declare ResizeHq2x(source, cible)
  
  DeclareModule_filtresadd_function(ResizeScale2xEx , #Filter_ResizeScale2x)
  Declare ResizeScale2x(source, cible)
  
  DeclareModule_filtresadd_function(ResizeXBRZ2xEx , #Filter_ResizeXBRZ2x)
  Declare ResizeXBRZ2x(source, cible)
EndDeclareModule


Module filtres
  
  #BLOCK_SIZE = 64; Taille des blocs pour cache-friendly (64 lignes par bloc)
  
  Enumeration
    #Asm_SSE    = $02000000
    #Asm_SSE2   = $04000000
    #Asm_SSE3   = $00000001
    #Asm_SSSE3  = $00000200
    #Asm_SSE41  = $00080000
    #Asm_SSE42  = $00100000
    #Asm_AVX    = $10000000
    #Asm_AVX2   = $00000020
    #Asm_AVX512 = $00010000
    
    ; --- Constantes de bits pour CPUID ---
    #CPUID_ECX_SSE3   = 1 << 0
    #CPUID_ECX_SSSE3  = 1 << 9
    #CPUID_ECX_SSE41  = 1 << 19
    #CPUID_ECX_SSE42  = 1 << 20
    #CPUID_ECX_AVX    = 1 << 28
    #CPUID_EDX_SSE    = 1 << 25
    #CPUID_EDX_SSE2   = 1 << 26
    #CPUID_EBX_AVX2   = 1 << 5
    #CPUID_EBX_AVX512 = 1 << 16 ; AVX512 Foundation
    
  EndEnumeration
  
  DetectCPU()
  
  Global Asm_Type = 0
  
  Structure Pixel32
    l.l
  EndStructure
  
  Structure Pixelarray
    l.l[0]
  EndStructure
  
  Structure PixelArray8
    b.a[0]
  EndStructure
  
  Structure array32
    l.l[0]
  EndStructure
  
  Structure PixelArray32
    pixel.l[0]
  EndStructure
  
  Structure Pixel8x4
    a.b
    r.b
    g.b
    b.b
  EndStructure
  
  ;--
  Macro clamp(c,a,b)
    If c < a : c = a : ElseIf c > b : c = b : EndIf
  EndMacro
  
  Macro clamp_rgb(r,g,b)
    If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
    If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
    If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
  EndMacro
  
  Macro clamp_argb(a,r,g,b)
    If a < 0 : a = 0 : ElseIf a > 255 : a = 255 : EndIf
    If r < 0 : r = 0 : ElseIf r > 255 : r = 255 : EndIf
    If g < 0 : g = 0 : ElseIf g > 255 : g = 255 : EndIf
    If b < 0 : b = 0 : ElseIf b > 255 : b = 255 : EndIf
  EndMacro
  
  ;--
  
  Macro seuil_rgb(seuil , r , g , b)
    If r < seuil : r = 0 : ElseIf r > 255 : r = 255 : EndIf
    If g < seuil : g = 0 : ElseIf g > 255 : g = 255 : EndIf
    If b < seuil : b = 0 : ElseIf b > 255 : b = 255 : EndIf
  EndMacro
  
  ;--
  
  Macro min(c,a,b)
    If a < b : c = a : Else : c = b : EndIf
  EndMacro  
  
  Macro max(c,a,b)
    If a > b : c = a : Else : c = b : EndIf
  EndMacro
  
  ;--  
  Macro min3(c, a, b, d)
    If a < b : c = a : Else : c = b : EndIf
    If d < c : c = d : EndIf
  EndMacro
  
  Macro max3(c, a, b, d)
    If a > b : c = a : Else : c = b : EndIf
    If d > c : c = d : EndIf
  EndMacro
  
  ;--
  Macro mib4(c, a, b, d, e)
    If a < b : c = a : Else : c = b : EndIf
    If d < c : c = d : EndIf
    If e < c : c = e : EndIf
  EndMacro
  
  Macro max4(c, a, b, d, e)
    If a > b : c = a : Else : c = b : EndIf
    If d > c : c = d : EndIf
    If e > c : c = e : EndIf
  EndMacro
  
  ;----------------------------------------------------------
  ; Macro pour lancer un traitement multi-thread
  Procedure Create_MultiThread_MT(proc , opt = 0) ; opt = nombre de threads imposé par le programme si différent de 0
    Protected i , nombre_de_treads_max 
    nombre_de_treads_max  = CountCPUs(#PB_System_CPUs) -1 ; maximum des threads - 1
    If opt = 0 : opt = FilterCtx\thread : EndIf ; nombre de thread demandé par l'utimisateur
    clamp( opt , 1 , nombre_de_treads_max)
    
    Protected Dim tr(opt)
    For i = 0 To opt - 1 : tr(i) = 0 : Next
    For i = 0 To opt - 1
      CopyStructure(@FilterCtx, @dim_FilterParams(i), FilterParams)
      dim_FilterParams(i)\thread_pos = i
      dim_FilterParams(i)\thread_max = opt
      tr(i) = CreateThread(proc, @dim_FilterParams(i))
      If tr(i) = 0
        Delay(10)
        tr(i) = CreateThread(proc, @dim_FilterParams(i))
        If tr(i) = 0
          Break
        EndIf
      EndIf
    Next
    For i = 0 To opt - 1 : If tr(i) And IsThread(tr(i)) > 0 : WaitThread(tr(i)) : EndIf : Next
    FreeArray(tr())
  EndProcedure
  
  ;----------------------------------------------------------
  Macro macro_calul_tread(lenght)
    
    If *FilterCtx\thread_max < 1 : *FilterCtx\thread_max = 1 : EndIf
    Protected thread_start, thread_stop
    thread_start = (lenght * *FilterCtx\thread_pos) / *FilterCtx\thread_max
    thread_stop  = (lenght * (*FilterCtx\thread_pos + 1)) / *FilterCtx\thread_max
    If thread_stop > lenght : thread_stop = lenght - 1: EndIf
    
  EndMacro
  ;-------------------------------------------------------------------
  
  ;test_taille = 0 , l'image d'entree et de sortie doivent etre de la meme taille 
  Procedure Filter_InitAndValidate(test_taille = 0)
    With FilterCtx
      ; lit les datasections des filtres
      Protected last_data ,t$
      Read.s \name
      Read.s \remarque
      Read.i \typ
      Read.i \subtype
      t$ = ""
      last_data = 0
      While t$ <> "XXX"
        Read.s t$
        If t$ = "XXX" : Break : EndIf
        \info[last_data] = t$
        Read.i \info_data(last_data , 0)
        Read.i \info_data(last_data , 1)
        Read.i \info_data(last_data , 2)
        last_data + 1
      Wend
      
      If \info_active : ProcedureReturn - 1: EndIf ; test si se n'est qu'une demmande d'info
      
      If \image[0] = 0
        MessageRequester(\name, "Image source manquante" , #PB_MessageRequester_Error)
        ProcedureReturn -2
      EndIf
      
      If \image[1] = 0
        MessageRequester(\name, "Image cible manquante" , #PB_MessageRequester_Error)
        ProcedureReturn -2
      EndIf
      
      If \image_lg[0] < 1 Or \image_lg[0] > 8192 Or \image_ht[0] < 1 Or  \image_ht[1] > 8192 
        MessageRequester(\name, "Taille d'image source invalide (inférieure à 1 ou supérieure à 8192 pixels)" , #PB_MessageRequester_Error)
        ProcedureReturn -2
      EndIf
      
      If test_taille = 0 ; si test_taille = 0 , les tailles des image d'entree et de sortie doivent etre identique
        If (\image_lg[0] <> \image_lg[1]) Or (\image_ht[0] <> \image_ht[1])
          MessageRequester(\name, "les images doivent etre de la meme taille" , #PB_MessageRequester_Error)
          ProcedureReturn -2
        EndIf
      EndIf
      
      If \thread < 1 : \thread = 1 : EndIf
      
      \addr[0] = \image[0]
      \addr[1] = \image[1]
      
      ;*param\image_lg[1] = *param\lg_cible
      ;*param\image_ht[1] = *param\ht_cible
      
      ;If *param\image_lg[0] <> param\image_lg[1] Or *param\image_ht[0] <> param\image_ht[1]
      ;MessageRequester(*param\name, "l'image source et l'image cible doivent etre de la meme taille" , #PB_MessageRequester_Error)
      ;ProcedureReturn
      ;EndIf
      
      ;If *param\image_lg[0] < 1 Or param\image_lg[1] < 1 Or *param\image_ht[0] < 1 Or  param\image_ht[1] < 1 
      ;MessageRequester(*param\name, "erreur de taille de l'image" , #PB_MessageRequester_Error)
      ;ProcedureReturn
      ;EndIf
      
    EndWith
    ProcedureReturn last_data
  EndProcedure
  
  ;-------------------------------------------------------------------
  
  
  Procedure.f max_2(a.f,b.f)
    If a>b 
      ProcedureReturn a
    Else
      ProcedureReturn b
    EndIf
  EndProcedure
  
  Procedure.f min_2(a.f,b.f)
    If a<b 
      ProcedureReturn a
    Else
      ProcedureReturn b
    EndIf
  EndProcedure
  
  
  Procedure.i Max_4(a.i, b.i, c.i, d.i)
    Protected maxValue = a
    If b > maxValue : maxValue = b : EndIf
    If c > maxValue : maxValue = c : EndIf
    If d > maxValue : maxValue = d : EndIf
    ProcedureReturn maxValue
  EndProcedure
  
  Procedure.i Max8(a.i, b.i, c.i, d.i, e.i, f.i, g.i, h.i)
    Protected maxValue = a
    If b > maxValue : maxValue = b : EndIf
    If c > maxValue : maxValue = c : EndIf
    If d > maxValue : maxValue = d : EndIf
    If e > maxValue : maxValue = e : EndIf
    If f > maxValue : maxValue = f : EndIf
    If g > maxValue : maxValue = g : EndIf
    If h > maxValue : maxValue = h : EndIf
    ProcedureReturn maxValue
  EndProcedure
  
  ;--
  
  Macro GetRGB(var,r,g,b)
    r = (var & $ff0000) >> 16
    g = (var & $00ff00) >> 8
    b = (var & $0000ff) 
  EndMacro 
  
  Macro GetARGB(var,a,r,g,b)
    a = (var & $ff000000) >> 24
    r = (var & $00ff0000) >> 16
    g = (var & $0000ff00) >> 8
    b = (var & $000000ff) 
  EndMacro
  
  
  ;--
  Procedure Clear_Data_Filter(*p.FilterParams)
    With *p
      For i = 0 To 3
        \image[i] = 0
        \image_lg[i] = 0
        \image_ht[i] = 0
      Next
      \thread_max = 0
      \thread_pos = 0
      \mask_type = 0
      \info_active = 0
      \typ = 0
      \name = ""
      \remarque = ""
      For i = 0 To 19
        ;*p\convolution3[i] = 0
        \addr[i] = 0
        \option[i] = 0
        \info[i] =""
        \info_data(i,0) = 0
        \info_data(i,1) = 0
        \info_data(i,2) = 0
      Next
      For i = 0 To 48
        \convol7[i] = 1
      Next
    EndWith
  EndProcedure
  
  
  ;-------------------------------------------------------------------
  ;-- conversion couleur
  Macro RGBtoGray(pixel , r, g, b)
    pixel = ((r * 54 + g * 183 + b * 18) >> 8)
  EndMacro
  
  Macro RGBtoGrayF(pixel , r, g, b)
    pixel = ((r) * 0.299 + (g) * 0.587 + (b) * 0.114)
    ;pixel = ((r * 77 + g * 150 + b * 29) >> 8)
  EndMacro
  
  Macro RGBtoGrayAvg(pixel , r, g, b)
    pixel = ((r + g + b) * $85 + 128) >> 8
  EndMacro
  
  Macro RGBtoGrayAvgF(pixel , r, g, b)
    pixel = ((r) + (g) + (b)) / 3
  EndMacro
  
  Macro RGBtoGray709(pixel , r, g, b)
    pixel = ((r) * 0.2126 + (g) * 0.7152 + (b) * 0.0722)
    ;pixel = ((r * 77 + g * 150 + b * 29) >> 8)
  EndMacro
  ;-------------------------------------------------------------------
  
  Procedure dither_grascale(*p.FilterParams)
    With *p
      Protected *source = \image[0]
      Protected *cible  = \image[1]
      Protected total = \image_lg[0] * \image_ht[0]
      Protected *srcPixel.Pixel32, *dstPixel.Pixel32, r, g, b
      Protected startPos = (\thread_pos * total) / \thread_max
      Protected endPos   = ((\thread_pos + 1) * total) / \thread_max
      If endPos >= total : endPos = total - 1 :EndIf
      For i = startPos To endPos
        *srcPixel = *source + (i << 2)
        *dstPixel = *cible  + (i << 2)
        getrgb(*srcPixel\l , r , g , b)
        *dstPixel\l = ((r * 54 + g * 183 + b * 18) >> 8) * $10101
      Next
    EndWith
  EndProcedure
  
  Macro dither(name1 , name2)
    ; Affichage des informations de configuration si demandé
    If param\info_active
      param\typ = #FilterType_Dithering
      param\name = name2
      param\remarque = "Attention, fonction non multithreadée"
      param\info[0] = "Nb de couleurs"
      param\info[1] = "Noir et blanc"
      param\info[2] = "Masque binaire"
      param\info_data(0,0) = 6 : param\info_data(0,1) = 64  : param\info_data(0,2) = 6 ; option[0] → niveaux
      param\info_data(1,0) = 0 : param\info_data(1,1) = 1  : param\info_data(1,2) = 0  ; [1] : N&B
      param\info_data(2,0) = 0 : param\info_data(2,1) = 2  : param\info_data(2,2) = 0  ; [2] : masque 
      ProcedureReturn
    EndIf
    
    Protected *source = *param\image[0]
    Protected *cible  = *param\image[1]
    Protected *mask   = *param\image[3]
    Protected lg = *param\image_lg[0], ht = *param\image_ht[0]
    Protected levels = *param\option[0]
    Protected i , var
    
    If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
    
    Protected thread = 1 ; CountCPUs(#PB_System_CPUs)
    Protected Dim tr(thread)
    
    ; Préparation image (gris ou copie)
    Protected *srcPixel.Pixel32, *dstPixel.Pixel32, r, g, b
    param\addr[0] = *source
    param\addr[1] = *cible
    If *param\option[1] : MultiThread_MT(@dither_grascale()) : Else : CopyMemory(*source, *cible, lg * ht * 4) : EndIf
    
    ; Table de quantification
    clamp(levels, 2,254)
    Protected *ndc = AllocateMemory(255)
    Protected Steping.f = 255.0 / (levels - 1)
    For i = 0 To 255
      var = i / Steping
      var = var * Steping
      PokeA(*ndc + i , var)
    Next
    
    *param\addr[2] = *ndc
    MultiThread_MT(name1) 
    If *param\mask And *param\option[2] : *param\mask_type = *param\option[2] - 1 : MultiThread_MT(@_mask()) : EndIf
    ; Libération mémoire
    FreeMemory(*ndc)
    FreeArray(tr())
  EndMacro
  
  ;-------------------------------------------------------------------
  
  Macro mask_binary_sp(logic)
    Protected i.l, maskVal.l
    Protected x, y, maskX, maskY, maskIndex
    Protected lg     = *p\image_lg[0]
    Protected ht     = *p\image_ht[0]
    Protected lgMask = *p\image_lg[3]
    Protected htMask = *p\image_ht[3]
    Protected ratioX.f = lgMask / lg
    Protected ratioY.f = htMask / ht
    Protected *srcPixel.Pixelarray
    Protected *dstPixel.Pixelarray
    Protected *makPixel.Pixelarray
    Protected totalPixels = lg * ht
    *srcPixel = *p\image[0]
    *dstPixel = *p\image[1] 
    *makPixel = *p\image[3]
    x = startPos % lg
    y = startPos / lg
    For i = 0 To totalPixels - 1
      maskX = Int(x * ratioX)
      maskY = Int(y * ratioY)
      maskIndex = (maskY * lgMask + maskX)
      maskVal     = *makPixel\l[maskIndex] & $FF
      If maskVal logic 127 : *dstPixel\l[i] = *srcPixel\l[i] : EndIf
      x + 1
      If x = lg : x = 0 : y + 1 : EndIf
    Next
  EndMacro
  
  Procedure mask_binary(*p.FilterParams)
    mask_binary_sp( < )
  EndProcedure
  
  Procedure mask_binary_inv(*p.FilterParams)
    mask_binary_sp( > )
  EndProcedure
  
  Macro mask_alpha_sp( v1 , v2)
    Protected i, a.l, r.l, g.l, b.l
    Protected a1.l, r1.l, g1.l, b1.l, maskVal.l, maskVal_inv.l
    Protected x, y, maskX, maskY, maskIndex
    Protected lg     = *p\image_lg[0]
    Protected ht     = *p\image_ht[0]
    Protected lgMask = *p\image_lg[3]
    Protected htMask = *p\image_ht[3]
    Protected ratioX.f = lgMask / lg
    Protected ratioY.f = htMask / ht
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected *makPixel.Pixel32
    Protected totalPixels = lg * ht
    x = startPos % lg
    y = startPos / lg
    For i = 0 To totalPixels - 1
      maskX = Int(x * ratioX)
      maskY = Int(y * ratioY)
      maskIndex = (maskY * lgMask + maskX) << 2
      *srcPixel = *p\image[0]  + (i << 2)
      *dstPixel = *p\image[1]   + (i << 2)
      *makPixel = *p\image[3]    + maskIndex
      maskVal     = *makPixel\l & $FF
      maskVal_inv = 255 - maskVal
      getargb(*srcPixel\l, a1, r1, g1, b1)
      getargb(*dstPixel\l, a , r , g , b )
      a = ((a  * v1 + a1 * v2) >> 8)
      r = ((r  * v1 + r1 * v2) >> 8)
      g = ((g  * v1 + g1 * v2) >> 8)
      b = ((b  * v1 + b1 * v2) >> 8)
      *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      x + 1
      If x = lg : x = 0 : y + 1 : EndIf
    Next
  EndMacro
  
  Procedure mask_alpha(*p.FilterParams)
    mask_alpha_sp(maskVal , maskVal_inv )
  EndProcedure
  
  Procedure mask_alpha_inv(*p.FilterParams)
    mask_alpha_sp(maskVal_inv , maskVal )
  EndProcedure
  
  ;-------------------------------------------------------------------
  
  Procedure mask_update(*p.FilterParams , last_data)
    Protected mask_type = *p\option[last_data]
    
    If *p\image[0] = 0 Or *p\image[1] = 0 Or *p\image[3] = 0 Or mask_type = 0: ProcedureReturn : EndIf 
    
    Select mask_type
      Case 1 : mask_binary(*p.FilterParams)
      Case 2 : mask_alpha(*p.FilterParams)
      Case 5 : mask_binary_inv(*p.FilterParams)
      Case 6 : mask_alpha_inv(*p.FilterParams)
    EndSelect
    
  EndProcedure
  
  ;-------------------------------------------------------------------
  
  ; charge une image et la convertie en 32bit
  Procedure load_image_32(nom,file$)
    Protected nom_p.i , temps_p.i , x.l , y.l , r.l,g.l,b.l , i.l
    Protected lg.l , ht.l , depth.l , temps.i  , dif.l , dif1.l
    If file$ = "" : ProcedureReturn 0 : EndIf
    If Not ReadFile( 0, file$)  : ProcedureReturn 0 : Else : CloseFile(0) : EndIf
    LoadImage(nom,file$)
    If Not IsImage(nom) : ProcedureReturn 0 : EndIf
    StartDrawing(ImageOutput(nom))
    Depth = OutputDepth()
    StopDrawing()
    If Depth=24
      CopyImage(nom,temps)
      FreeImage(nom)
      StartDrawing(ImageOutput(temps))
      temps_p = DrawingBuffer()
      lg = ImageWidth(temps)
      ht = ImageHeight(temps)
      dif = DrawingBufferPitch() - (lg * 3)
      StopDrawing()
      CreateImage(nom,lg,ht,32)
      StartDrawing(ImageOutput(nom))
      nom_p = DrawingBuffer()
      StopDrawing()
      For y=0 To ht-1
        For x=0 To lg-1
          i = ((y * lg) + x) * 3
          r = PeekA(temps_p + i + 2 + dif1)
          g = PeekA(temps_p + i + 1 + dif1)
          b = PeekA(temps_p + i + 0 + dif1)
          PokeL(nom_p + ((y * lg)+ x)*4 , (r << 16) + (g << 8) + b)
        Next
        dif1 = dif1 + dif
      Next
      FreeImage(temps) ; supprime l'image 24bits
    EndIf
    ProcedureReturn 1
  EndProcedure
  
  
  ;-------------------------------------------------------------------
  
  Macro macro_set_image_sp_sp( var , a , b , c)
    FilterCtx\image[var] = a
    FilterCtx\image_lg[var] = b
    FilterCtx\image_ht[var] = c
  EndMacro
  
  Macro macro_set_image_sp( var)
    If IsImage(image) = 0
      macro_set_image_sp_sp( var , 0 , 0 , 0)
      ProcedureReturn 0
    Else
      If StartDrawing(ImageOutput(image))
        macro_set_image_sp_sp( var , DrawingBuffer() , ImageWidth(image) , ImageHeight(image))
        StopDrawing()
        ProcedureReturn 1
      Else
        macro_set_image_sp_sp( var , 0 , 0 , 0)
        ProcedureReturn 0
      EndIf
    EndIf
  EndMacro
  
  Procedure Set_Source(image) : macro_set_image_sp(0) : EndProcedure
  Procedure Set_Cible(image)  : macro_set_image_sp(1) : EndProcedure
  Procedure Set_Mix(image)    : macro_set_image_sp(2) : EndProcedure
  Procedure Set_Mask(image)   : macro_set_image_sp(3) : EndProcedure
  
  ; --
  Macro macro_set_image_spEx( var)
    macro_set_image_sp_sp( var , adresse_memoire_image , lg , ht) 
  EndMacro
  
  Procedure Set_SourceEx(adresse_memoire_image , lg , ht) : macro_set_image_spEx(0) : EndProcedure
  Procedure Set_CibleEX(adresse_memoire_image , lg , ht)  : macro_set_image_spEx(1) : EndProcedure
  Procedure Set_MixEX(adresse_memoire_image , lg , ht)    : macro_set_image_spEx(2) : EndProcedure
  Procedure Set_MaskEX(adresse_memoire_image , lg , ht)   : macro_set_image_spEx(3) : EndProcedure
  
  ;-------------------------------------------------------------------
  
  Procedure Set_thread(var)
    FilterCtx\thread = var
  EndProcedure
  
  Procedure Set_language(var)
    clamp(var , 0 , 4)
    FilterCtx\asm = var
  EndProcedure
  
  Procedure get_language()
    ProcedureReturn FilterCtx\asm
  EndProcedure
  
  Procedure get_language_max()
    ProcedureReturn FilterCtx\asm_max
  EndProcedure
  
  
  ;-------------------------------------------------------------------
  
  Procedure LaplacianPyramidBlur_ScaleImage(*src, oldW, oldH, *dst, newW, newH)
    Protected x,y,sx,sy
    Protected fx.f, fy.f, dx, dy
    Protected px00, px01, px10, px11
    Protected r,g,b,a
    Protected v,v1
    
    For y = 0 To newH-1
      If newH > 1
        fy = y * (oldH-1) / (newH-1)
      Else
        fy = 0
      EndIf
      sy = Int(fy) : dy = fy - sy
      
      For x = 0 To newW-1
        If newW > 1
          fx = x * (oldW-1) / (newW-1)
        Else
          fx = 0
        EndIf
        sx = Int(fx) : dx = fx - sx
        
        CLAMP(sx, 0, oldW-1)
        CLAMP(sy, 0, oldH-1)
        
        v  = sx+1 : CLAMP(v ,0, oldW-1)
        v1 = sy+1 : CLAMP(v1,0, oldH-1)
        
        px00 = PeekL(*src + ((sy * oldW + sx) * 4))
        px01 = PeekL(*src + ((sy * oldW + v ) * 4))
        px10 = PeekL(*src + ((v1 * oldW + sx) * 4))
        px11 = PeekL(*src + ((v1 * oldW + v ) * 4))
        
        r = ((px00>>16&255)*(1-dx)*(1-dy) + (px01>>16&255)*dx*(1-dy) + (px10>>16&255)*(1-dx)*dy + (px11>>16&255)*dx*dy)
        g = ((px00>>8 &255)*(1-dx)*(1-dy) + (px01>>8 &255)*dx*(1-dy) + (px10>>8 &255)*(1-dx)*dy + (px11>>8 &255)*dx*dy)
        b = ((px00    &255)*(1-dx)*(1-dy) + (px01    &255)*dx*(1-dy) + (px10    &255)*(1-dx)*dy + (px11    &255)*dx*dy)
        a = ((px00>>24&255)*(1-dx)*(1-dy) + (px01>>24&255)*dx*(1-dy) + (px10>>24&255)*(1-dx)*dy + (px11>>24&255)*dx*dy)
        
        PokeL(*dst + ((y*newW + x)*4), (a<<24)|(r<<16)|(g<<8)|b)
      Next
    Next
  EndProcedure
  
  
  Procedure LaplacianPyramidBlur_UpscaleImage(*src, oldW, oldH, *dst, newW, newH)
    LaplacianPyramidBlur_ScaleImage(*src, oldW, oldH, *dst, newW, newH)
  EndProcedure
  
  Procedure LaplacianPyramidBlur_BlurBuffer(*buf, w, h, radius)
    If radius < 1 : ProcedureReturn : EndIf
    
    Protected *tmp = AllocateMemory(w*h*4)
    Protected x,y,i,px,idx
    Protected sr,sg,sb,sa,c
    
    ; Horizontal
    For y=0 To h-1
      For x=0 To w-1
        sr=0:sg=0:sb=0:sa=0:c=0
        For i=-radius To radius
          px = x+i : CLAMP(px,0,w-1)
          idx = (y*w+px)*4
          sa + PeekA(*buf+idx+3)
          sr + PeekA(*buf+idx+2)
          sg + PeekA(*buf+idx+1)
          sb + PeekA(*buf+idx+0)
          c+1
        Next
        idx = (y*w+x)*4
        PokeA(*tmp+idx+3, sa/c)
        PokeA(*tmp+idx+2, sr/c)
        PokeA(*tmp+idx+1, sg/c)
        PokeA(*tmp+idx+0, sb/c)
      Next
    Next
    
    ; Vertical
    For x=0 To w-1
      For y=0 To h-1
        sr=0:sg=0:sb=0:sa=0:c=0
        For i=-radius To radius
          px = y+i : CLAMP(px,0,h-1)
          idx = (px*w+x)*4
          sa + PeekA(*tmp+idx+3)
          sr + PeekA(*tmp+idx+2)
          sg + PeekA(*tmp+idx+1)
          sb + PeekA(*tmp+idx+0)
          c+1
        Next
        idx = (y*w+x)*4
        PokeA(*buf+idx+3, sa/c)
        PokeA(*buf+idx+2, sr/c)
        PokeA(*buf+idx+1, sg/c)
        PokeA(*buf+idx+0, sb/c)
      Next
    Next
    
    FreeMemory(*tmp)
  EndProcedure
  ;-------------------------------------------------------------------
  
  ;----------------------------------------------------------
  ;-- DetectCPU()
  Procedure DetectCPU()
    ; On ne détecte qu'une seule fois
    ;Static Done = #False
    ;If Done : ProcedureReturn Asm_Type : EndIf
    
    Protected eax.l, ebx.l, ecx.l, edx.l
    
    ; --- Phase 1 : Flags Standard (EAX = 1) ---
    CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
      !mov eax, 1
      !cpuid
      !mov [p.v_eax], eax
      !mov [p.v_ebx], ebx
      !mov [p.v_ecx], ecx
      !mov [p.v_edx], edx
    CompilerElse
      ; Pour le Backend C, on utilise l'assembleur en ligne format GCC
      !asm volatile ("cpuid" : "=a" (v_eax), "=b" (v_ebx), "=c" (v_ecx), "=d" (v_edx) : "a" (1));
    CompilerEndIf
    
    ; Hiérarchie des extensions (on monte en puissance)
    If edx & #CPUID_EDX_SSE   : Asm_Type = #Asm_SSE   : EndIf
    If edx & #CPUID_EDX_SSE2  : Asm_Type = #Asm_SSE2  : EndIf
    If ecx & #CPUID_ECX_SSE3  : Asm_Type = #Asm_SSE3  : EndIf
    If ecx & #CPUID_ECX_SSSE3 : Asm_Type = #Asm_SSSE3 : EndIf
    If ecx & #CPUID_ECX_SSE41 : Asm_Type = #Asm_SSE41 : EndIf
    If ecx & #CPUID_ECX_SSE42 : Asm_Type = #Asm_SSE42 : EndIf
    If ecx & #CPUID_ECX_AVX   : Asm_Type = #Asm_AVX   : EndIf
    
    ; --- Phase 2 : Flags Etendus (EAX = 7, ECX = 0) ---
    ; Requis pour AVX2 et AVX512
    CompilerIf #PB_Compiler_Backend = #PB_Backend_Asm
      !mov eax, 7
      !xor ecx, ecx
      !cpuid
      !mov [p.v_ebx], ebx
    CompilerElse
      !asm volatile ("cpuid" : "=a" (v_eax), "=b" (v_ebx), "=c" (v_ecx), "=d" (v_edx) : "a" (7), "c" (0));
    CompilerEndIf
    
    If ebx & #CPUID_EBX_AVX2   : Asm_Type = #Asm_AVX2   : EndIf
    If ebx & #CPUID_EBX_AVX512 : Asm_Type = #Asm_AVX512 : EndIf
    
    FilterCtx\asm_max = 0
    Select Asm_Type
      Case #Asm_SSE2   : FilterCtx\asm_max = 1
      Case #Asm_SSE42  : FilterCtx\asm_max = 2
      Case #Asm_AVX2   : FilterCtx\asm_max = 3
      Case #Asm_AVX512 : FilterCtx\asm_max = 4
    EndSelect
    
    ;Done = #True
    ProcedureReturn Asm_Type
  EndProcedure
  
  ;-- 
  
  ; --- Définition des tailles par thread ---
  #Reg_GP_Size  = 128   ; 16 registres * 8 octets
  #Reg_XMM_Size = 256   ; 16 registres * 16 octets
  #Reg_YMM_Size = 512   ; 16 registres * 32 octets
  #Reg_ZMM_Size = 2048  ; 32 registres * 64 octets
  
  Global *Buffer_GP  = AllocateMemory(#Reg_GP_Size  * 128)
  Global *Buffer_XMM = AllocateMemory(#Reg_XMM_Size * 128)
  Global *Buffer_YMM = AllocateMemory(#Reg_YMM_Size * 128)
  Global *Buffer_ZMM = AllocateMemory(#Reg_ZMM_Size * 128)
  
  Procedure Push_Reg(*FilterCtx.FilterParams)
    Protected *pos = *Buffer_GP + (FilterCtx\thread_pos * #Reg_GP_Size)
    !mov rax,[p.p_pos]
    !mov [rax + 0],   rbx
    !mov [rax + 8],   rcx
    !mov [rax + 16],  rdx
    !mov [rax + 24],  rsi
    !mov [rax + 32],  rdi
    !mov [rax + 40],  rbp
    !mov [rax + 48],  r8
    !mov [rax + 56],  r9
    !mov [rax + 64],  r10
    !mov [rax + 72],  r11
    !mov [rax + 80],  r12
    !mov [rax + 88],  r13
    !mov [rax + 96],  r14
    !mov [rax + 104], r15
  EndProcedure
  
  Macro macro_Push_Reg_XMM(v1, v2)
    !mov rdx , rax
    !add rdx , v1
    !movdqu [rdx], xmm#v2
  EndMacro
  
  Procedure Push_Reg_XMM(*FilterCtx.FilterParams)
    Protected *pos = *Buffer_XMM + (FilterCtx\thread_pos * #Reg_XMM_Size)
    !mov rax, [p.p_pos]
    !movdqu [rax + 0], xmm0
    !movdqu [rax + 16], xmm1
    !movdqu [rax + 32], xmm2
    !movdqu [rax + 48], xmm3
    !movdqu [rax + 64], xmm4
    !movdqu [rax + 80], xmm5
    !movdqu [rax + 96], xmm6
    !movdqu [rax + 112], xmm7
    !movdqu [rax + 128], xmm8
    !movdqu [rax + 144], xmm9
    !movdqu [rax + 160], xmm10
    !movdqu [rax + 176], xmm11
    !movdqu [rax + 192], xmm12
    !movdqu [rax + 208], xmm13
    !movdqu [rax + 224], xmm14
    !movdqu [rax + 240], xmm15
  EndProcedure
  
  
  Procedure Pop_reg(*FilterCtx.FilterParams)
    Protected *pos = *Buffer_GP + (FilterCtx\thread_pos * #Reg_GP_Size)
    !mov rax, [p.p_pos]
    !mov rbx, [rax + 0]
    !mov rcx, [rax + 8]
    !mov rdx, [rax + 16]
    !mov rsi, [rax + 24]
    !mov rdi, [rax + 32]
    !mov rbp, [rax + 40]
    !mov r8,  [rax + 48]
    !mov r9,  [rax + 56]
    !mov r10, [rax + 64]
    !mov r11, [rax + 72]
    !mov r12, [rax + 80]
    !mov r13, [rax + 88]
    !mov r14, [rax + 96]
    !mov r15, [rax + 104]
  EndProcedure
  
  Procedure Pop_Reg_XMM(*FilterCtx.FilterParams)
    Protected *pos = *Buffer_XMM + (FilterCtx\thread_pos * #Reg_XMM_Size)
    !mov rax, [p.p_pos]
    !movdqu xmm0,  [rax + 0]
    !movdqu xmm1,  [rax + 16]
    !movdqu xmm2,  [rax + 32]
    !movdqu xmm3,  [rax + 48]
    !movdqu xmm4,  [rax + 64]
    !movdqu xmm5,  [rax + 80]
    !movdqu xmm6,  [rax + 96]
    !movdqu xmm7,  [rax + 112]
    !movdqu xmm8,  [rax + 128]
    !movdqu xmm9,  [rax + 144]
    !movdqu xmm10, [rax + 160]
    !movdqu xmm11, [rax + 176]
    !movdqu xmm12, [rax + 192]
    !movdqu xmm13, [rax + 208]
    !movdqu xmm14, [rax + 224]
    !movdqu xmm15, [rax + 240]
  EndProcedure
  
  Procedure Push_Reg_YMM(*FilterCtx.FilterParams)
    Protected *pos = *Buffer_YMM + (FilterCtx\thread_pos * #Reg_YMM_Size)
    !mov rax, [p.p_pos]
    !vmovdqu [rax + 0],   ymm0
    !vmovdqu [rax + 32],  ymm1
    !vmovdqu [rax + 64],  ymm2
    !vmovdqu [rax + 96],  ymm3
    !vmovdqu [rax + 128], ymm4
    !vmovdqu [rax + 160], ymm5
    !vmovdqu [rax + 192], ymm6
    !vmovdqu [rax + 224], ymm7
    !vmovdqu [rax + 256], ymm8
    !vmovdqu [rax + 288], ymm9
    !vmovdqu [rax + 320], ymm10
    !vmovdqu [rax + 352], ymm11
    !vmovdqu [rax + 384], ymm12
    !vmovdqu [rax + 416], ymm13
    !vmovdqu [rax + 448], ymm14
    !vmovdqu [rax + 480], ymm15
  EndProcedure
  
  Procedure Pop_Reg_YMM(*FilterCtx.FilterParams)
    Protected *pos = *Buffer_YMM + (FilterCtx\thread_pos * #Reg_YMM_Size)
    !mov rax, [p.p_pos]
    !vmovdqu [rax + 0*32],  ymm0
    !vmovdqu [rax + 1*32],  ymm1
    !vmovdqu [rax + 2*32],  ymm2
    !vmovdqu [rax + 3*32],  ymm3
    !vmovdqu [rax + 4*32],  ymm4
    !vmovdqu [rax + 5*32],  ymm5
    !vmovdqu [rax + 6*32],  ymm6
    !vmovdqu [rax + 7*32],  ymm7
    !vmovdqu [rax + 8*32],  ymm8
    !vmovdqu [rax + 9*32],  ymm9
    !vmovdqu [rax + 10*32], ymm10
    !vmovdqu [rax + 11*32], ymm11
    !vmovdqu [rax + 12*32], ymm12
    !vmovdqu [rax + 13*32], ymm13
    !vmovdqu [rax + 14*32], ymm14
    !vmovdqu [rax + 15*32], ymm15
    !vzeroupper
  EndProcedure
  
  Procedure Push_Reg_ZMM(*FilterCtx.FilterParams)
    Protected *pos = *Buffer_ZMM + (FilterCtx\thread_pos * #Reg_ZMM_Size)
    !mov rax, [p.p_pos]
    ; Rappel: 32 registres en AVX-512
    !vmovdqu64 [rax + 0*64], zmm0
    !vmovdqu64 [rax + 1*64], zmm1
    ; ...
    !vmovdqu64 [rax + 31*64], zmm31
  EndProcedure
  
  Procedure Pop_Reg_ZMM(*FilterCtx.FilterParams)
    Protected *pos = *Buffer_ZMM + (FilterCtx\thread_pos * #Reg_ZMM_Size)
    !mov rax, [p.p_pos]
    !vmovdqu64 zmm0,  [rax + 0*64]
    ; ...
    !vmovdqu64 zmm31, [rax + 31*64]
  EndProcedure
  
  ;-------------------------------------------------------------------
  
  ;-- IncludeFile
  EnableExplicit 
  ;-- Blur
  IncludePath "filtres\blur\"
  
  ;#Blur_Classic
  XIncludeFile "blur_box_sse2.pbi"
  XIncludeFile "blur_box_sse4.pbi"
  ;XIncludeFile "blur_box_avx2.pbi"
  XIncludeFile "blur_box.pbi"
  
  XIncludeFile "blur_box_Guillossien.pbi"
  XIncludeFile "SummedArea.pbi"
  XIncludeFile "blur_IIR.pbi"
  XIncludeFile "stackblur.pbi"
  XIncludeFile "CircularMeanblur2.pbi"
  
  ;CompilerIf #PB_Compiler_OS = #PB_OS_Linux
  ;#Blur_Directional
  XIncludeFile "blur_radial.pbi"
  XIncludeFile "blur_radial_IIR.pbi"
  XIncludeFile "blur_spiral_IIR.pbi"
  XIncludeFile "Blur_spiral_stochastic.pbi"
  XIncludeFile "Blur_spiral_Accumulation.pbi"
  XIncludeFile "Blur_spiral_Separable.pbi"
  XIncludeFile "DirectionalBlur.pbi"
  XIncludeFile "MotionBlur.pbi"
  XIncludeFile "ZoomBlur.pbi"
  XIncludeFile "RotationalBlur.pbi"
  XIncludeFile "TwistBlur.pbi"
  XIncludeFile "CameraShakeBlur.pbi"
  XIncludeFile "SpinBlur.pbi"
  ;#Blur_Gaussian
  XIncludeFile "GaussianBlur_Conv.pbi"
  XIncludeFile "SeparableGaussian.pbi"
  XIncludeFile "HeatDiffusionBlur.pbi"
  ;#Blur_EdgeAware
  XIncludeFile "blur_bilateral.pbi"
  XIncludeFile "Edge_Aware.pbi"
  XIncludeFile "GuidedFilterColor.pbi"
  XIncludeFile "WLSBlur.pbi"
  XIncludeFile "DomainTransformFilter.pbi"
  XIncludeFile "MultiScaleBilateralBlur.pbi"
  XIncludeFile "BilateralLaplacianBlur.pbi"
  XIncludeFile "SmartBlur.pbi"
  XIncludeFile "SurfaceBlur.pbi"
  ;#Blur_Adaptive
  XIncludeFile "blur_median.pbi"
  XIncludeFile "AnisotropicBlur.pbi"
  XIncludeFile "KuwaharaBlur.pbi"
  XIncludeFile "NLMBlur.pbi"
  XIncludeFile "RollingGuidanceFilter.pbi"
  ;#Blur_Stochastic
  XIncludeFile "PoissonDiskBlur.pbi"
  XIncludeFile "StochasticBlur.pbi"
  XIncludeFile "MonteCarloBlur.pbi"
  XIncludeFile "FrostedGlassBlur.pbi"
  ;#Blur_Optical
  XIncludeFile "OpticalBlur.pbi"
  XIncludeFile "BokehBlur.pbi"
  XIncludeFile "PolygonBokehBlur.pbi"
  XIncludeFile "CatEyeBokehBlur.pbi"
  XIncludeFile "ChromaticBokehBlur.pbi"
  XIncludeFile "AdvancedChromaticBokehBlur.pbi"
  XIncludeFile "DepthAwareBlur.pbi"
  XIncludeFile "DefocusBlur.pbi"
  XIncludeFile "LensBlur.pbi"
  ;#Blur_MultiScale
  XIncludeFile "LaplacianPyramidBlur.pbi"
  XIncludeFile "GaussianPyramidBlur.pbi"
  XIncludeFile "HDRBloomLaplace.pbi"
  ;#Blur_Morphological
  XIncludeFile "MorphBlur.pbi"
  XIncludeFile "MorphOpenCloseBlur.pbi"
  XIncludeFile "ErosionBlur.pbi"
  XIncludeFile "DilationBlur.pbi"
  XIncludeFile "BalancedMorphBlur.pbi"
  ;Blur_Artistic
  XIncludeFile "OilPaintBlur.pbi"
  XIncludeFile "WatercolorBlur.pbi"
  XIncludeFile "TiltShift.pbi"
  XIncludeFile "IrisBlur.pbi"
  XIncludeFile "PastelBlur.pbi"
  XIncludeFile "CharcoalBlur.pbi"
  XIncludeFile "InkBlur.pbi"
  XIncludeFile "DreamGlow.pbi"
  ;#Blur_Specialized
  XIncludeFile "UnsharpMask.pbi"
  XIncludeFile "SharpenBlur.pbi"
  XIncludeFile "LowPassBlur.pbi"
  ;#Blur_Advanced
  XIncludeFile "PermutohedralLattice.pbi"
  
  
  ;-- edge_detection
  IncludePath "filtres\edge_detection\"
  ;Filtres basés sur les gradients (dérivées premières)
  XIncludeFile "roberts.pbi"
  XIncludeFile "Prewitt.pbi"
  XIncludeFile "sobel.pbi"
  XIncludeFile "sobel_4d.pbi"
  XIncludeFile "scharr.pbi"
  XIncludeFile "scharr_4d.pbi"
  XIncludeFile "kirsch.pbi"
  XIncludeFile "robinson.pbi"
  XIncludeFile "FreiChen.pbi"
  XIncludeFile "Kayyali.pbi"
  XIncludeFile "NevatiaBabu.pbi"
  XIncludeFile "DerivativeOfGaussian.pbi"
  ;Filtres basés sur les dérivées secondes (Laplaciens)
  XIncludeFile "Laplacian.pbi"
  XIncludeFile "LaplacianOfGaussian.pbi"
  XIncludeFile "DoG.pbi"
  XIncludeFile "MarrHildreth.pbi"
  XIncludeFile "MexicanHat.pbi"
  XIncludeFile "ZeroCrossing.pbi"
  ;Méthodes avancées / hybrides
  XIncludeFile "canny.pbi"
  XIncludeFile "CannyDeriche.pbi"
  XIncludeFile "PhaseCongruency.pbi"
  XIncludeFile "Gabor.pbi"
  XIncludeFile "Steerable.pbi"
  XIncludeFile "StructuredEdgeDetection.pbi"
  XIncludeFile "HED.pbi"
  ;Méthodes morphologiques
  XIncludeFile "MorphologicalGradient.pbi"
  XIncludeFile "BeucherGradient.pbi"
  XIncludeFile "TopHatEdge.pbi"
  ;Méthodes multi-échelle
  XIncludeFile "LaplacianPyramidSharpen.pbi"
  XIncludeFile "MultiscaleEdge.pbi"
  XIncludeFile "WaveletEdge.pbi"
  ;Méthodes spécialisées
  XIncludeFile "ColorEdgeDetection.pbi"
  XIncludeFile "TextureEdge.pbi"
  XIncludeFile "SubpixelEdge.pbi"
  XIncludeFile "OrientedEdge.pbi"
  
  IncludePath "filtres\dither\"
  ; #Dither_ErrorDiffusion - Diffusion d'erreur classique
  XIncludeFile "FloydDither.pbi"
  XIncludeFile "FalseFloydSteinberg.pbi"
  XIncludeFile "JJNDither.pbi"
  XIncludeFile "StuckiDither.pbi"
  XIncludeFile "StevensonArceDither.pbi"
  XIncludeFile "BurkesDither.pbi"
  XIncludeFile "SierraDither.pbi"
  XIncludeFile "SierraTwoRowDither.pbi"
  XIncludeFile "SierraLiteDither.pbi"
  XIncludeFile "AtkinsonDither.pbi"
  XIncludeFile "ShiauFanDither.pbi"
  XIncludeFile "MinAvgErr.pbi"
  ; #Dither_Ordered - Dithering par matrices ordonnées
  XIncludeFile "Bayer2x2.pbi"
  XIncludeFile "Bayer4x4.pbi"
  XIncludeFile "Bayer8x8.pbi"
  XIncludeFile "ClusteredDot.pbi"
  XIncludeFile "DispersedDot.pbi"
  XIncludeFile "HalftoneScreen.pbi"
  XIncludeFile "ThresholdMatrix.pbi"
  ; #Dither_Random - Bruit aléatoire pur
  XIncludeFile "RandomDither.pbi"
  ; #Dither_Stochastic - Bruit structuré/optimisé
  XIncludeFile "BlueNoiseDither.pbi"
  XIncludeFile "GreenNoiseDither.pbi"
  XIncludeFile "VoidAndCluster.pbi"
  ; #Dither_Adaptive - Méthodes adaptatives au contenu
  XIncludeFile "AdaptiveDither.pbi"
  XIncludeFile "VariableErrorDiffusion.pbi"
  ;#Dither_Hybrid - Méthodes hybrides/space-filling curves
  XIncludeFile "RiemersmaHilbert.pbi"
  XIncludeFile "RiemersmaError.pbi"
  XIncludeFile "KiteDither.pbi"
  ; #Dither_Fast - Optimisations ultra-rapides
  XIncludeFile "LiteDither.pbi"
  
  
  
  IncludePath "filtres\color_adjust"
  XIncludeFile "Balance.pbi"
  XIncludeFile "Brightness.pbi"
  XIncludeFile "Contrast.pbi"
  XIncludeFile "Exposure.pbi"
  XIncludeFile "Gamma.pbi"
  XIncludeFile "Normalize_Color.pbi"
  XIncludeFile "Saturation.pbi"
  XIncludeFile "AutoOtsuThreshold.pbi"
  
  IncludePath "filtres\couleur\"
  XIncludeFile "grayscale.pbi"
  XIncludeFile "BlackAndWhite.pbi"
  XIncludeFile "Sepia.pbi"
  XIncludeFile "Negatif.pbi"
  XIncludeFile "Colorize.pbi"
  XIncludeFile "RaviverCouleurs.pbi"
  XIncludeFile "teinte.pbi"
  XIncludeFile "ColorPermutation.pbi"
  XIncludeFile "Color_hue.pbi"
  XIncludeFile "Posterize.pbi"
  XIncludeFile "color_effect.pbi"
  XIncludeFile "ChannelSwap.pbi"
  XIncludeFile "FalseColour.pbi"
  XIncludeFile "Dichromatic.pbi"
  XIncludeFile "PencilImage.pbi"
  XIncludeFile "SquareLaw_Lightening.pbi"
  XIncludeFile "Color.pbi"
  XIncludeFile "Hollow.pbi"
  XIncludeFile "Bend.pbi"
  
  IncludePath "filtres\artistic\"
  ; #Artistic_Light - Effets de lumière (glow, HDR, etc.)
  XIncludeFile "Glow_IIR.pbi"
  XIncludeFile "Fake_HDR.pbi"
  XIncludeFile "hdr_artistic.pbi"
  XIncludeFile "dragan.pbi"
  ; #Artistic_Material - Simulation matériaux (crayon, fusain, etc.)
  XIncludeFile "pencil.pbi"
  XIncludeFile "CharcoalImage.pbi"
  XIncludeFile "sketch.pbi"
  XIncludeFile "watercolor.pbi"
  XIncludeFile "gouache.pbi"
  XIncludeFile "pastel.pbi"
  XIncludeFile "impasto.pbi"
  ; #Artistic_Other - Autres effets artistiques
  XIncludeFile "Emboss.pbi"
  XIncludeFile "Histogram.pbi"
  XIncludeFile "FlowLiquify.pbi"
  XIncludeFile "DisplacementMap.pbi"
  XIncludeFile "Dilate.pbi"
  XIncludeFile "Fractalius.pbi"
  XIncludeFile "cartoon.pbi"
  XIncludeFile "crosshatching.pbi"
  XIncludeFile "BrushedMetal.pbi"
  
  XIncludeFile "FlowPaint.pbi"
  
  IncludePath "filtres\texture\"
  XIncludeFile "Mosaic.pbi"
  XIncludeFile "HexMosaic.pbi"
  XIncludeFile "IrregularHexMosaic.pbi"
  XIncludeFile "Diffuse.pbi"
  XIncludeFile "Glitch.pbi"
  XIncludeFile "Kaleidoscope.pbi"
  XIncludeFile "Emboss_bump.pbi"
  XIncludeFile "mettalic_effect.pbi"
  
  
  IncludePath "filtres\deform\"
  XIncludeFile "FlipH.pbi"
  XIncludeFile "FlipV.pbi"
  XIncludeFile "Rotate.pbi"
  XIncludeFile "Perspective.pbi"
  XIncludeFile "PerspectiveSimple.pbi"
  XIncludeFile "Translate.pbi"
  XIncludeFile "Spherize.pbi"
  XIncludeFile "Spiralize.pbi"
  XIncludeFile "Ellipze.pbi"
  XIncludeFile "Ripple.pbi"
  XIncludeFile "PinchBulge.pbi"
  XIncludeFile "WaveCircular.pbi"
  XIncludeFile "Lens.pbi"
  XIncludeFile "Tile.pbi"
  XIncludeFile "Perspective2.pbi"
  XIncludeFile "PerspectiveHomography.pbi"
  XIncludeFile "Twirl.pbi"
  XIncludeFile "Shear.pbi"
  XIncludeFile "Barrel.pbi"
  XIncludeFile "FishEye.pbi"
  XIncludeFile "Polar_Transform.pbi"
  XIncludeFile "Kaleidoscope2.pbi"
  XIncludeFile "Mirror.pbi"
  XIncludeFile "Wave.pbi"
  XIncludeFile "Zigzag.pbi"
  XIncludeFile "Glass.pbi"
  XIncludeFile "Squeeze.pbi"
  XIncludeFile "Mesh_Warp.pbi"
  XIncludeFile "Liquify.pbi"
  XIncludeFile "Cylindrical_Projection.pbi"
  XIncludeFile "Spherical_Projection.pbi"
  XIncludeFile "Displace_Map.pbi"
  ;XIncludeFile "deform_Bend.pbi"
  
  ;IncludePath "filtres\texture2\"
  ;XIncludeFile "texture_synthesis.pbi"
  
  IncludePath "filtres\Color_Space\"
  XIncludeFile "RgbToYuv.pbi"
  XIncludeFile "YUVtoRGB.pbi"
  XIncludeFile "RGBtoYIQ.pbi"
  XIncludeFile "YIQtoRGB.pbi"
  XIncludeFile "RGBtoLAB.pbi"
  XIncludeFile "LABToRGB.pbi"
  XIncludeFile "RGBtoHSV.pbi"               
  XIncludeFile "HSVtoRGB.pbi"                  
  XIncludeFile "RGBtoHSL.pbi"                  
  XIncludeFile "HSLtoRGB.pbi"
  XIncludeFile "RGBtoHUE.pbi"
  XIncludeFile "HUEtoRGB.pbi"
  XIncludeFile "RGBtoYCbCr.pbi"
  XIncludeFile "YCbCrtoRGB.pbi"
  XIncludeFile "RGBtoCMYK.pbi"
  XIncludeFile "CMYKtoRGB.pbi"
  XIncludeFile "RGBtoXYZ.pbi"
  XIncludeFile "XYZtoRGB.pbi"
  XIncludeFile "LABtoLCH.pbi"
  XIncludeFile "LCHtoLAB.pbi"
  
  IncludePath "filtres\Convolution\"
  XIncludeFile "Convol3x3.pbi"
  XIncludeFile "Convol5x5.pbi"
  XIncludeFile "Convol7x7.pbi"
  
  IncludePath "filtres\mix\"
  XIncludeFile "mix.pbi"
  
  ;IncludePath "filtres\other\"
  ;XIncludeFile "fire.pbi"
  ;CompilerEndIf
  
  IncludePath "filtres\scale\"
  XIncludeFile "resize2xSaI.pbi"
  XIncludeFile "ResizeAdvMAME2x.pbi"
  XIncludeFile "ResizeBell.pbi"
  XIncludeFile "ResizeBicubic.pbi"
  XIncludeFile "ResizeBilinear.pbi"
  XIncludeFile "ResizeEPX.pbi"
  XIncludeFile "ResizeHermite.pbi"
  XIncludeFile "ResizeHq2x.pbi"
  XIncludeFile "ResizeHq3x.pbi"
  XIncludeFile "ResizeHq4x.pbi"
  XIncludeFile "ResizeLanczos.pbi"
  XIncludeFile "ResizeMitchell.pbi"
  XIncludeFile "ResizeNearest.pbi"
  XIncludeFile "ResizeScale2x.pbi"
  XIncludeFile "ResizeSuperEagle.pbi"
  XIncludeFile "ResizeXBRZ2x.pbi"
  XIncludeFile "ResizeXBRZ3.pbi"
  XIncludeFile "ResizeXBRZ4.pbi"
  XIncludeFile "ResizeXBRZ5.pbi"
  XIncludeFile "ResizeXBRZ6Ex.pbi"
  XIncludeFile "SeamCarving_Energy.pbi"
EndModule

; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 1420
; FirstLine = 1399
; Folding = ------------
; Optimizer
; EnableXP
; DPIAware
; CPU = 5
; Compiler = PureBasic 6.21 (Windows - x64)