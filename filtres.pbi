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
    #Convolution_Custom            ; Matrices de convolution personnalisées
    
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
    #Filter_Blur_Box                    ; Box blur ultra-rapide | CPU: ★★★★★ | MEM: ★★★★★
    #Filter_Guillossien                 ; Box blur optimisé | CPU: ★★★★★ | MEM: ★★★★★
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
    
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    ; ▓ COLOR SPACE CONVERSION FILTERS
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    
    ; ─── ColorSpace_YUV ───
    #Filter_RgbToYuv                    ; RGB → YUV
    #Filter_YUVtoRGB                    ; YUV → RGB
    #Filter_RGB_YUV_Modif               ; Modification en espace YUV
    
    ; ─── ColorSpace_YIQ ───
    #Filter_RGBtoYIQ                    ; RGB → YIQ
    #Filter_YIQtoRGB                    ; YIQ → RGB
    #Filter_RGB_YIQ_Modif               ; Modification en espace YIQ
    
    ; ─── ColorSpace_LAB ───
    #Filter_RGBtoLAB                    ; RGB → LAB
    #Filter_RGB_LAB_Modif               ; Modification en espace LAB
                                        ; #Filter_LABtoRGB                  ; LAB → RGB (à implémenter)
    
    ; ─── ColorSpace_Other ───
    ; #Filter_RGBtoHSV                  ; RGB → HSV (à implémenter)
    ; #Filter_HSVtoRGB                  ; HSV → RGB (à implémenter)
    ; #Filter_RGBtoHSL                  ; RGB → HSL (à implémenter)
    ; #Filter_HSLtoRGB                  ; HSL → RGB (à implémenter)
    
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
    ; ▓ OTHER / MISC FILTERS
    ; ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
    
    #Filter_other_fire
    ;#FilterType_Other
    
  EndEnumeration
  
  Structure parametre
    source.i       ; buffer source
    mix.i          ; buffer mix
    cible.i        ; buffer cible
    mask.i         ; buffer mask
    source_mask.i  ; buffer source1 (utile si plusieurs filtres utilisés d'affilée)
    tempo.i        ; buffer temporaire pour ne pas modifier la source (utile si plusieurs filtres utilisés d'affilée)
    
    lg.l           ; longeur de l'image source en pixel
    ht.l           ; hauteur de l'image source en pixel
    lg_mix.l
    ht_mix.l
    lg_mask.l
    ht_mask.l
    
    thread_max.l         ; nombre total de threads
    thread_max_x.l       ; max threads pour la passe X
    thread_max_y.l       ; max threads pour la passe Y
    thread_pos.l         ; position du thread courant
    thread_total_time.l  ; mesures de performance en ms
    thread_time_x.l      ; mesures de performance pour la passe en x
    thread_time_y.l      ; mesures de performance pour la passe en y
    passe_count_x.l      ; sert pour calcul le meillieur nombre dee thread 
    passe_count_y.l
    
    anime.l
    
    addr.i[20]     ; adreesse temporaire utiliser en interne pour les threads
    mask_type.l    ; definis le type de mask , binaire ou non
    option.f[20]
    convolution3.f[11]
    info_active.l
    typ.l
    SubType.l
    name.s
    remarque.s
    info.s[20] 
    Array info_data.l(20,2)
  EndStructure
  Global param.parametre
  Global.parametre Dim dim_param(128) ; 128 thread max
  
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
  ;-- DeclareModule Blur
  ;#Blur_Classic
  DeclareModule_filtresadd_function(Blur_box , #Filter_Blur_box)
  DeclareModule_filtresadd_function(Guillossien , #Filter_Guillossien)
  DeclareModule_filtresadd_function(Blur_IIR , #Filter_Blur_IIR)
  DeclareModule_filtresadd_function(StackBlur , #Filter_StackBlur)
  DeclareModule_filtresadd_function(CircularMeanblur , #filter_CircularMeanblur)
  ;#Blur_Directional
  DeclareModule_filtresadd_function(RadialBlur , #Filter_RadialBlur)
  DeclareModule_filtresadd_function(RadialBlur_IIR , #Filter_RadialBlur_IIR)
  DeclareModule_filtresadd_function(SpiralBlur_IIR , #Filter_SpiralBlur_IIR)
  DeclareModule_filtresadd_function(spiral_stochastic , #Filter_spiral_stochastic)
  DeclareModule_filtresadd_function(spiral_Accumulation , #Filter_spiral_Accumulation)
  DeclareModule_filtresadd_function(spiral_Separable , #Filter_spiral_Separable)
  DeclareModule_filtresadd_function(DirectionalBoxBlur , #Filter_DirectionalBoxBlur)
  DeclareModule_filtresadd_function(MotionBlur , #Filter_MotionBlur)
  DeclareModule_filtresadd_function(ZoomBlur , #Filter_ZoomBlur)
  DeclareModule_filtresadd_function(RotationalBlur , #Filter_RotationalBlur)
  DeclareModule_filtresadd_function(TwistBlur , #Filter_TwistBlur)
  DeclareModule_filtresadd_function(CameraShakeBlur , #Filter_CameraShakeBlur)
  DeclareModule_filtresadd_function(SpinBlur , #Filter_SpinBlur)
  ;#Blur_Gaussian
  DeclareModule_filtresadd_function(GaussianBlur_Conv , #Filter_GaussianBlur_Conv)
  DeclareModule_filtresadd_function(SeparableGaussian , #Filter_SeparableGaussian)
  DeclareModule_filtresadd_function(HeatDiffusionBlur , #Filter_HeatDiffusionBlur)
  ;#Blur_EdgeAware
  DeclareModule_filtresadd_function(Bilateral , #Filter_Bilateral)
  DeclareModule_filtresadd_function(Edge_Aware , #Filter_Edge_Aware)
  DeclareModule_filtresadd_function(GuidedFilterColor , #Filter_GuidedFilterColor)
  DeclareModule_filtresadd_function(WLSBlur , #filter_WLSBlur)
  DeclareModule_filtresadd_function(DomainTransform , #filter_DomainTransform)
  DeclareModule_filtresadd_function(MultiScaleBilateralBlur , #filter_MultiScaleBilateralBlur)
  DeclareModule_filtresadd_function(BilateralLaplacianBlur , #filter_BilateralLaplacianBlur)
  DeclareModule_filtresadd_function(SmartBlur , #Filter_SmartBlur)
  DeclareModule_filtresadd_function(SurfaceBlur , #Filter_SurfaceBlur)
  ;#Blur_Adaptive
  DeclareModule_filtresadd_function(MedianBlur , #Filter_MedianBlur)
  DeclareModule_filtresadd_function(AnisotropicBlur , #Filter_AnisotropicBlur)
  DeclareModule_filtresadd_function(KuwaharaBlur , #Filter_KuwaharaBlur)
  DeclareModule_filtresadd_function(NLMBlur , #filter_NLMBlur)
  DeclareModule_filtresadd_function(RollingGuidanceFilter , #filter_RollingGuidanceFilter)
  ;#Blur_Stochastic
  DeclareModule_filtresadd_function(PoissonDiskBlur , #Filter_PoissonDiskBlur)
  DeclareModule_filtresadd_function(StochasticBlur , #filter_StochasticBlur)
  DeclareModule_filtresadd_function(MonteCarloBlur , #filter_MonteCarloBlur)
  DeclareModule_filtresadd_function(FrostedGlassBlur , #filter_FrostedGlassBlur)
  ;#Blur_Optical
  DeclareModule_filtresadd_function(OpticalBlur , #Filter_OpticalBlur)
  DeclareModule_filtresadd_function(BokehBlur, #filter_BokehBlur)
  DeclareModule_filtresadd_function(PolygonBokehBlur , #filter_PolygonBokehBlur)
  DeclareModule_filtresadd_function(CatEyeBokehBlur , #filter_CatEyeBokehBlur)
  DeclareModule_filtresadd_function(ChromaticBokehBlur , #filter_ChromaticBokehBlur)
  DeclareModule_filtresadd_function(AdvancedChromaticBokehBlur , #filter_AdvancedChromaticBokehBlur)
  DeclareModule_filtresadd_function(DepthAwareBlur , #Filter_DepthAwareBlur)
  DeclareModule_filtresadd_function(DefocusBlur , #Filter_DefocusBlur)
  DeclareModule_filtresadd_function(LensBlur , #Filter_LensBlur)
  ;#Blur_MultiScale
  DeclareModule_filtresadd_function(LaplacianPyramidBlur , #filter_LaplacianPyramidBlur)
  DeclareModule_filtresadd_function(GaussianPyramidBlur , #filter_GaussianPyramidBlur)
  DeclareModule_filtresadd_function(HDRBloomLaplace , #filter_HDRBloomLaplace)
  ;#Blur_Morphological
  DeclareModule_filtresadd_function(MorphBlur , #filter_MorphBlur)
  DeclareModule_filtresadd_function(MorphOpenCloseBlur , #filter_MorphOpenCloseBlur)
  DeclareModule_filtresadd_function(ErosionBlur , #filter_ErosionBlur)
  DeclareModule_filtresadd_function(DilationBlur , #Filter_DilationBlur)
  DeclareModule_filtresadd_function(BalancedMorphBlur , #filter_BalancedMorphBlur)
  ;Blur_Artistic
  DeclareModule_filtresadd_function(OilPaintBlur , #Filter_OilPaintBlur)
  DeclareModule_filtresadd_function(WatercolorBlur , #Filter_WatercolorBlur)
  DeclareModule_filtresadd_function(TiltShift , #Filter_TiltShift)
  DeclareModule_filtresadd_function(IrisBlur , #Filter_IrisBlur)
  DeclareModule_filtresadd_function(PastelBlur , #Filter_PastelBlur)
  DeclareModule_filtresadd_function(CharcoalBlur , #Filter_CharcoalBlur)
  DeclareModule_filtresadd_function(InkBlur , #Filter_InkBlur)
  DeclareModule_filtresadd_function(DreamGlow , #Filter_DreamGlow)
  ;#Blur_Specialized
  DeclareModule_filtresadd_function(UnsharpMask , #Filter_UnsharpMask)
  DeclareModule_filtresadd_function(SharpenBlur , #Filter_SharpenBlur)
  DeclareModule_filtresadd_function(LowPassBlur , #filter_LowPassBlur)
  ;#Blur_Advanced
  DeclareModule_filtresadd_function(PermutohedralLattice , #Filter_PermutohedralLattice)
  
  ;-- DeclareModule Edge Detection
  ;Filtres basés sur les gradients (dérivées premières)
  DeclareModule_filtresadd_function(Roberts , #Filter_Roberts)
  DeclareModule_filtresadd_function(Prewitt , #Filter_Prewitt)
  DeclareModule_filtresadd_function(sobel , #Filter_sobel)
  DeclareModule_filtresadd_function(sobel_4d , #Filter_sobel_4d)
  DeclareModule_filtresadd_function(scharr , #Filter_scharr)
  DeclareModule_filtresadd_function(scharr_4d , #Filter_scharr_4d)
  DeclareModule_filtresadd_function(kirsch , #Filter_kirsch)
  DeclareModule_filtresadd_function(robinson , #Filter_robinson)
  DeclareModule_filtresadd_function(FreiChen , #Filter_FreiChen)
  DeclareModule_filtresadd_function(Kayyali , #Filter_Kayyali)
  DeclareModule_filtresadd_function(NevatiaBabu , #Filter_NevatiaBabu)
  DeclareModule_filtresadd_function(DerivativeOfGaussian , #Filter_DerivativeOfGaussian)
  ;Filtres basés sur les dérivées secondes (Laplaciens)
  DeclareModule_filtresadd_function(Laplacian , #Filter_Laplacian)
  DeclareModule_filtresadd_function(LaplacianOfGaussian , #Filter_LaplacianOfGaussian)
  DeclareModule_filtresadd_function(DoG , #Filter_DoG)
  DeclareModule_filtresadd_function(MarrHildreth , #Filter_MarrHildreth)
  DeclareModule_filtresadd_function(MexicanHat , #Filter_MexicanHat)
  DeclareModule_filtresadd_function(ZeroCrossing , #Filter_ZeroCrossing)
  ;Méthodes avancées / hybrides
  DeclareModule_filtresadd_function(canny , #Filter_canny)
  DeclareModule_filtresadd_function(CannyDeriche , #Filter_CannyDeriche)
  DeclareModule_filtresadd_function(PhaseCongruency , #Filter_PhaseCongruency)
  DeclareModule_filtresadd_function(Gabor , #Filter_Gabor)
  DeclareModule_filtresadd_function(Steerable , #Filter_Steerable)
  DeclareModule_filtresadd_function(StructuredEdgeDetection , #Filter_StructuredEdgeDetection)
  DeclareModule_filtresadd_function(hed , #Filter_hed)
  ;Méthodes morphologiques
  DeclareModule_filtresadd_function(MorphologicalGradient , #Filter_MorphologicalGradient)
  DeclareModule_filtresadd_function(BeucherGradient , #Filter_BeucherGradient)
  DeclareModule_filtresadd_function(TopHatEdge , #Filter_TopHatEdge)
  ;Méthodes multi-échelle
  DeclareModule_filtresadd_function(LaplacianPyramidSharpen , #filter_LaplacianPyramidSharpen)
  DeclareModule_filtresadd_function(MultiscaleEdge , #Filter_MultiscaleEdge)
  DeclareModule_filtresadd_function(WaveletEdge , #Filter_WaveletEdge)
  ;Méthodes spécialisées
  DeclareModule_filtresadd_function(ColorEdgeDetection , #Filter_ColorEdgeDetection)
  DeclareModule_filtresadd_function(TextureEdge , #Filter_TextureEdge)
  DeclareModule_filtresadd_function(SubpixelEdge , #Filter_SubpixelEdge)
  DeclareModule_filtresadd_function(OrientedEdge , #Filter_OrientedEdge)
  ; #Dither_ErrorDiffusion - Diffusion d'erreur classique
  DeclareModule_filtresadd_function(FloydDither , #Filter_FloydDither)
  DeclareModule_filtresadd_function(FalseFloydSteinberg , #Filter_FalseFloydSteinberg)
  DeclareModule_filtresadd_function(JJNDither , #Filter_JJNDither)
  DeclareModule_filtresadd_function(StuckiDither , #Filter_StuckiDither)
  DeclareModule_filtresadd_function(StevensonArce , #Filter_StevensonArce)
  DeclareModule_filtresadd_function(BurkesDither , #Filter_BurkesDither)
  DeclareModule_filtresadd_function(SierraDither , #Filter_SierraDither)
  DeclareModule_filtresadd_function(SierraTwoRow , #Filter_SierraTwoRow)
  DeclareModule_filtresadd_function(SierraLiteDither , #Filter_SierraLiteDither)
  DeclareModule_filtresadd_function(AtkinsonDither , #Filter_AtkinsonDither)
  DeclareModule_filtresadd_function(ShiauFanDither , #Filter_ShiauFanDither)
  DeclareModule_filtresadd_function(MinAvgErr , #Filter_MinAvgErr)
  ; #Dither_Ordered - Dithering par matrices ordonnées
  DeclareModule_filtresadd_function(Bayer2x2 , #Filter_Bayer2x2Dither)
  DeclareModule_filtresadd_function(Bayer4x4 , #Filter_Bayer4x4Dither)
  DeclareModule_filtresadd_function(Bayer8x8 , #Filter_Bayer8x8Dither)
  DeclareModule_filtresadd_function(ClusteredDot , #Filter_ClusteredDot)
  DeclareModule_filtresadd_function(DispersedDot , #Filter_DispersedDot)
  DeclareModule_filtresadd_function(HalftoneScreen , #Filter_HalftoneScreen)
  DeclareModule_filtresadd_function(ThresholdMatrix , #Filter_ThresholdMatrix)
  ; #Dither_Random - Bruit aléatoire pur
  DeclareModule_filtresadd_function(RandomDither , #Filter_RandomDither)
  ; #Dither_Stochastic - Bruit structuré/optimisé
  DeclareModule_filtresadd_function(BlueNoiseDither , #Filter_BlueNoiseDither)
  DeclareModule_filtresadd_function(GreenNoiseDither , #Filter_GreenNoiseDither)
  DeclareModule_filtresadd_function(VoidAndCluster , #Filter_VoidAndCluster)
  ; #Dither_Adaptive - Méthodes adaptatives au contenu
  DeclareModule_filtresadd_function(AdaptiveDither , #Filter_AdaptiveDither)
  DeclareModule_filtresadd_function(VariableErrorDiffusion , #Filter_VariableErrorDiffusion)
  ; #Dither_Hybrid - Méthodes hybrides/space-filling curves
  DeclareModule_filtresadd_function(RiemersmaHilbert , #Filter_RiemersmaHilbert)
  DeclareModule_filtresadd_function(RiemersmaError , #Filter_RiemersmaError)
  DeclareModule_filtresadd_function(KiteDither , #Filter_KiteDither)
  ; #Dither_Fast - Optimisations ultra-rapides
  DeclareModule_filtresadd_function(LiteDither , #Filter_LiteDither)
  
  
  DeclareModule_filtresadd_function(Balance , #Filter_Balance)
  DeclareModule_filtresadd_function(Brightness , #Filter_Brightness)
  DeclareModule_filtresadd_function(Contrast , #Filter_Contrast)
  DeclareModule_filtresadd_function(Exposure , #Filter_Exposure)
  DeclareModule_filtresadd_function(Gamma , #Filter_Gamma)
  DeclareModule_filtresadd_function(Normalize_Color, #Filter_Normalize_Color)
  DeclareModule_filtresadd_function(Saturation , #Filter_Saturation)
  DeclareModule_filtresadd_function(AutoOtsuThreshold , #Filter_AutoOtsuThreshold)
  
  
  ; ═══ Conversion / Base ═══
  DeclareModule_filtresadd_function(grayscale , #Filter_grayscale)
  DeclareModule_filtresadd_function(BlackAndWhite , #Filter_BlackAndWhite)
  DeclareModule_filtresadd_function(Sepia , #Filter_Sepia)
  DeclareModule_filtresadd_function(Negatif , #Filter_Negatif)
  ; ═══ Saturation ═══
  DeclareModule_filtresadd_function(Colorize , #Filter_Colorize)
  DeclareModule_filtresadd_function(RaviverCouleurs , #Filter_VibrantColors)
  ; ═══ Teinte ═══
  DeclareModule_filtresadd_function(teinte , #Filter_HueRotation)
  DeclareModule_filtresadd_function(ColorPermutation , #Filter_HueReplace)
  DeclareModule_filtresadd_function(Color_hue , #Filter_SelectiveDesaturation)
  ; ═══ Quantification ═══
  DeclareModule_filtresadd_function(Posterize , #Filter_Posterize)
  ; ═══ Canaux ═══
  DeclareModule_filtresadd_function(color_effect , #Filter_ChannelMix)
  DeclareModule_filtresadd_function(ChannelSwap , #Filter_ChannelSwap)
  ; ═══ Effets spéciaux ═══
  DeclareModule_filtresadd_function(FalseColour , #Filter_FalseColor)
  DeclareModule_filtresadd_function(Dichromatic , #Filter_Dichromatic)
  DeclareModule_filtresadd_function(PencilImage , #Filter_PencilSketch)
  DeclareModule_filtresadd_function(SquareLaw_Lightening , #Filter_SquareLawLightening)
  ; ═══ Sélectifs ═══
  DeclareModule_filtresadd_function(Color , #Filter_SelectiveColor)
  DeclareModule_filtresadd_function(Hollow , #Filter_Hollow)
  ; ═══ Divers / Déformation ═══
  DeclareModule_filtresadd_function(Bend , #Filter_Bend)
  
  
  
  DeclareModule_filtresadd_function(GlowEffect_IIR , #Filter_GlowEffect_IIR)
  DeclareModule_filtresadd_function(FakeHDR , #Filter_Fake_Hdr)
  DeclareModule_filtresadd_function(hdr_artistic , #Filter_hdr_artistic)
  DeclareModule_filtresadd_function(dragan , #Filter_dragan)
  
  DeclareModule_filtresadd_function(pencil , #Filter_pencil)
  DeclareModule_filtresadd_function(CharcoalImage , #Filter_CharcoalImage)
  DeclareModule_filtresadd_function(sketch , #Filter_sketch)
  DeclareModule_filtresadd_function(watercolor , #Filter_watercolor)
  DeclareModule_filtresadd_function(gouache , #Filter_gouache)
  DeclareModule_filtresadd_function(pastel , #Filter_pastel)
  DeclareModule_filtresadd_function(impasto , #Filter_impasto)
  
  DeclareModule_filtresadd_function(Emboss , #Filter_Emboss)
  DeclareModule_filtresadd_function(Histogram , #Filter_Histogram)
  DeclareModule_filtresadd_function(Mosaic , #Filter_Mosaic)
  DeclareModule_filtresadd_function(HexMosaic , #Filter_HexMosaic)
  DeclareModule_filtresadd_function(IrregularHexMosaic , #Filter_IrregularHexMosaic)
  DeclareModule_filtresadd_function(Glitch , #Filter_Glitch)
  DeclareModule_filtresadd_function(Kaleidoscope , #Filter_Kaleidoscope)
  DeclareModule_filtresadd_function(FlowLiquify ,  #Filter_FlowLiquify)
  DeclareModule_filtresadd_function(DisplacementMap , #Filter_DisplacementMap2)
  DeclareModule_filtresadd_function(Dilate , #Filter_Dilate)
  
  DeclareModule_filtresadd_function(Emboss_bump , #Filter_Emboss_bump)
  DeclareModule_filtresadd_function(Diffuse , #Filter_Diffuse)
  
  DeclareModule_filtresadd_function(Fractalius , #Filter_Fractalius)
  DeclareModule_filtresadd_function(cartoon , #Filter_cartoon)
  DeclareModule_filtresadd_function(crosshatching , #Filter_crosshatching)
  
  ;DeclareModule_filtresadd_function(mettalic_effect , #Filter_mettalic_effect)
  
  ;DeclareModule_filtresadd_function(Convolution3x3,#Filter_Convolution3x3)
  
  DeclareModule_filtresadd_function(FlipH , #Filter_FlipH)
  DeclareModule_filtresadd_function(FlipV , #Filter_FlipV)
  DeclareModule_filtresadd_function(Rotate , #Filter_Rotate)
  DeclareModule_filtresadd_function(Perspective , #Filter_Perspective)
  DeclareModule_filtresadd_function(PerspectiveSimple , #Filter_PerspectiveSimple)
  DeclareModule_filtresadd_function(Translate , #Filter_Translate)
  DeclareModule_filtresadd_function(Spherize , #Filter_Spherize)
  DeclareModule_filtresadd_function(Spiralize , #Filter_Spiralize)
  DeclareModule_filtresadd_function(Ellipze , #Filter_Ellipse)
  DeclareModule_filtresadd_function(Ripple , #Filter_Ripple)
  DeclareModule_filtresadd_function(PinchBulge , #Filter_PinchBulge)
  DeclareModule_filtresadd_function(WaveCircular , #Filter_WaveCircular)
  DeclareModule_filtresadd_function(Lens , #Filter_Lens)
  DeclareModule_filtresadd_function(Tile , #Filter_Tile)
  DeclareModule_filtresadd_function(Perspective2 , #Filter_Perspective2)
  DeclareModule_filtresadd_function(PerspectiveHomography , #Filter_PerspectiveHomography)
  DeclareModule_filtresadd_function(Twirl , #Filter_Twirl)
  DeclareModule_filtresadd_function(Shear , #Filter_Shear)
  DeclareModule_filtresadd_function(Barrel , #Filter_Barrel)
  DeclareModule_filtresadd_function(Fish_Eye , #Filter_Fish_Eye)
  DeclareModule_filtresadd_function(Polar_Transform , #Filter_Polar_Transform)
  DeclareModule_filtresadd_function(Kaleidoscope2 , #Filter_Kaleidoscope2)
  DeclareModule_filtresadd_function(Mirror , #Filter_Mirror)
  DeclareModule_filtresadd_function(Wave , #Filter_Wave)
  DeclareModule_filtresadd_function(Zigzag , #Filter_Zigzag)
  DeclareModule_filtresadd_function(Glass , #Filter_Glass)
  DeclareModule_filtresadd_function(Squeeze , #Filter_Squeeze)
  DeclareModule_filtresadd_function(Mesh_Warp , #Filter_MeshWarp)
  DeclareModule_filtresadd_function(Liquify , #Filter_Liquify)
  DeclareModule_filtresadd_function(Cylindrical_Projection , #Filter_CylindricalProjection)
  DeclareModule_filtresadd_function(Spherical_Projection , #Filter_SphericalProjection)
  DeclareModule_filtresadd_function(Displace_Map , #Filter_DisplacementMap)
  ;DeclareModule_filtresadd_function(deform_Bend , #Filter_deform_Bend)
  
  DeclareModule_filtresadd_function(texture_synthesis , #Filter_texture_synthesis)
  
  DeclareModule_filtresadd_function(RgbToYuv , #Filter_RgbToYuv)
  DeclareModule_filtresadd_function(YUVtoRGB , #Filter_YUVtoRGB)
  DeclareModule_filtresadd_function(RGB_YUV_Modif , #Filter_RGB_YUV_Modif)
  DeclareModule_filtresadd_function(RGBtoYIQ , #Filter_RGBtoYIQ)
  DeclareModule_filtresadd_function(YIQtoRGB , #Filter_YIQtoRGB)
  DeclareModule_filtresadd_function(RGB_YIQ_Modif , #Filter_RGB_YIQ_Modif)
  DeclareModule_filtresadd_function(RGBtoLAB , #Filter_RGBtoLAB)
  DeclareModule_filtresadd_function(RGB_LAB_Modif , #Filter_RGB_LAB_Modif)
  
  DeclareModule_filtresadd_function(Blend_additive , #Filter_Blend_Additive)
  DeclareModule_filtresadd_function(Blend_additive_inverted , #Filter_Blend_additive_inverted)
  DeclareModule_filtresadd_function(Blend_alphablend , #Filter_Blend_alphablend)
  DeclareModule_filtresadd_function(Blend_RMSColor , #Filter_Blend_RMSColor)
  DeclareModule_filtresadd_function(Blend_And , #Filter_Blend_And)
  DeclareModule_filtresadd_function(Blend_Average , #Filter_Blend_Average)
  DeclareModule_filtresadd_function(Blend_LightBlend , #Filter_Blend_LightBlend)
  DeclareModule_filtresadd_function(Blend_IntensityBoost , #Filter_Blend_IntensityBoost)
  DeclareModule_filtresadd_function(Blend_BrushUp , #Filter_Blend_BrushUp)
  DeclareModule_filtresadd_function(Blend_Burn , #Filter_Blend_Burn)
  DeclareModule_filtresadd_function(Blend_SubtractiveDodge , #Filter_Blend_SubtractiveDodge)
  DeclareModule_filtresadd_function(Blend_ColorBurn , #Filter_Blend_ColorBurn)
  DeclareModule_filtresadd_function(Blend_ColorDodge , #Filter_Blend_ColorDodge)
  DeclareModule_filtresadd_function(Blend_Contrast , #Filter_Blend_Contrast)
  DeclareModule_filtresadd_function(Blend_Cosine , #Filter_Blend_Cosine)
  DeclareModule_filtresadd_function(Blend_CrossFading , #Filter_Blend_CrossFading)
  DeclareModule_filtresadd_function(Blend_InverseMultiply , #Filter_Blend_InverseMultiply)
  DeclareModule_filtresadd_function(Blend_Darken , #Filter_Blend_Darken)
  DeclareModule_filtresadd_function(Blend_SubtractiveBlend , #Filter_Blend_SubtractiveBlend)
  DeclareModule_filtresadd_function(Blend_Difference , #Filter_Blend_Difference)
  DeclareModule_filtresadd_function(Blend_Div , #Filter_Blend_Div)
  DeclareModule_filtresadd_function(Blend_SoftAdd , #Filter_Blend_SoftAdd)
  DeclareModule_filtresadd_function(Blend_SoftLightBoost , #Filter_Blend_SoftLightBoost)
  DeclareModule_filtresadd_function(Blend_Exponentiale , #Filter_Blend_Exponentiale)
  DeclareModule_filtresadd_function(Blend_Fade , #Filter_Blend_Fade)
  DeclareModule_filtresadd_function(Blend_Fence , #Filter_Blend_Fence)
  DeclareModule_filtresadd_function(Blend_Freeze , #Filter_Blend_Freeze)
  DeclareModule_filtresadd_function(Blend_Glow , #Filter_Blend_Glow)
  DeclareModule_filtresadd_function(Blend_HardContrast , #Filter_Blend_HardContrast)
  DeclareModule_filtresadd_function(Blend_Hardlight , #Filter_Blend_Hardlight)
  DeclareModule_filtresadd_function(Blend_TanBlend , #Filter_Blend_TanBlend)
  DeclareModule_filtresadd_function(Blend_HardlTangent , #Filter_Blend_HardTangent)
  DeclareModule_filtresadd_function(Blend_Heat , #Filter_Blend_Heat)
  DeclareModule_filtresadd_function(Blend_InHale , #Filter_Blend_InHale)
  DeclareModule_filtresadd_function(Blend_Intensify , #Filter_Blend_Intensify)
  DeclareModule_filtresadd_function(Blend_CosBlend , #Filter_Blend_CosBlend)
  DeclareModule_filtresadd_function(Blend_Interpolation , #Filter_Blend_Interpolation)
  DeclareModule_filtresadd_function(Blend_InvBurn , #Filter_Blend_InvBurn)
  DeclareModule_filtresadd_function(Blend_InvColorBurn , #Filter_Blend_InvColorBurn)
  DeclareModule_filtresadd_function(Blend_InvColorDodge , #Filter_Blend_InvColorDodge)
  DeclareModule_filtresadd_function(Blend_InvDodge , #Filter_Blend_InvDodge)
  DeclareModule_filtresadd_function(Blend_Lighten , #Filter_Blend_Lighten)
  DeclareModule_filtresadd_function(Blend_LinearBurn , #Filter_Blend_LinearBurn)
  DeclareModule_filtresadd_function(Blend_LinearLight , #Filter_Blend_LinearLight)
  DeclareModule_filtresadd_function(Blend_Logarithmic , #Filter_Blend_Logarithmic)
  DeclareModule_filtresadd_function(Blend_Mean , #Filter_Blend_Mean)
  DeclareModule_filtresadd_function(Blend_ColorVivify , #Filter_Blend_ColorVivify)
  DeclareModule_filtresadd_function(Blend_Multiply , #Filter_Blend_Multiply)
  DeclareModule_filtresadd_function(Blend_Negation , #Filter_Blend_Negation)
  DeclareModule_filtresadd_function(Blend_PinLight , #Filter_Blend_PinLight)
  DeclareModule_filtresadd_function(Blend_Or , #Filter_Blend_Or)
  DeclareModule_filtresadd_function(Blend_Overlay , #Filter_Blend_Overlay)
  DeclareModule_filtresadd_function(Blend_Pegtop_soft_light , #Filter_Blend_Pegtop_soft_light)
  DeclareModule_filtresadd_function(Blend_quadritic , #Filter_Blend_quadritic)
  DeclareModule_filtresadd_function(Blend_Screen , #Filter_Blend_Screen)
  DeclareModule_filtresadd_function(Blend_SoftColorBurn , #Filter_Blend_SoftColorBurn)
  DeclareModule_filtresadd_function(Blend_SoftColorDodge , #Filter_Blend_SoftColorDodge)
  DeclareModule_filtresadd_function(Blend_SoftLight , #Filter_Blend_SoftLight)
  DeclareModule_filtresadd_function(Blend_SoftOverlay , #Filter_Blend_SoftOverlay)
  DeclareModule_filtresadd_function(Blend_Stamp , #Filter_Blend_Stamp)
  DeclareModule_filtresadd_function(Blend_Subtractive , #Filter_Blend_Subtractive)
  DeclareModule_filtresadd_function(Blend_Xor , #Filter_Blend_Xor)
  
  
  DeclareModule_filtresadd_function(fire , #Filter_other_fire)
  
  Declare active_asm(var)
  
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
  EndEnumeration
  Global Asm_Type = 0
  
  Structure Pixel8
    b.b[0]
  EndStructure
  
  Structure Pixel32
    l.l
  EndStructure
  
  Structure Pixelarray
    l.l[0]
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
  ;-- DetectCPU()
  Procedure DetectCPU()
    If Asm_Type <> 0 : ProcedureReturn : EndIf
    Global Asm_active = 0
    
    Protected eax.l, ebx.l, ecx.l, edx.l
    ; --- Lire les flags standard ---
    CompilerIf #PB_Compiler_Backend <> #PB_Backend_C
      !mov eax, 1
      !cpuid
      !mov [p.v_eax], eax
      !mov [p.v_ebx], ebx
      !mov [p.v_ecx], ecx
      !mov [p.v_edx], edx
    CompilerElse
    
    CompilerEndIf
    
    ; --- SSE / SSE2 / SSE3 / SSSE3 / SSE4.1 / SSE4.2 ---
    If edx & #Asm_SSE    : Asm_Type = #Asm_SSE   : EndIf
    If edx & #Asm_SSE2   : Asm_Type = #Asm_SSE2  : EndIf
    If ecx & #Asm_SSE3   : Asm_Type = #Asm_SSE3  : EndIf
    If ecx & #Asm_SSSE3  : Asm_Type = #Asm_SSSE3 : EndIf
    If ecx & #Asm_SSE41  : Asm_Type = #Asm_SSE41 : EndIf
    If ecx & #Asm_SSE42  : Asm_Type = #Asm_SSE42 : EndIf
    If ecx & #Asm_AVX    : Asm_Type = #Asm_AVX   : EndIf
    
    ; --- Pour AVX2, lire CPUID leaf 7 ---
    CompilerIf #PB_Compiler_Backend <> #PB_Backend_C
      !mov eax, 7
      !XOr ecx, ecx
      !cpuid
      !mov [p.v_ebx], ebx
      !mov [p.v_ecx], ecx
      !mov [p.v_edx], edx
    CompilerElse

    CompilerEndIf
    
    If ebx & #Asm_AVX2    : Asm_Type = #Asm_AVX2   : EndIf
    If ebx & #Asm_AVX512  : Asm_Type = #Asm_AVX512 : EndIf
    
  EndProcedure
  
  
  Procedure active_asm(var)
    var = var & 1
    Asm_active = var
  EndProcedure
  
  ;----------------------------------------------------------
  ; Macro pour lancer un traitement multi-thread
  Procedure MultiThread_MT(proc , opt = 0)
    Protected i
    Protected thread = CountCPUs(#PB_System_CPUs)
    clamp(thread, 1 , 128)
    ;thread = 1
    If opt > 0 : clamp( opt , 1 , thread) : thread = opt : EndIf
    
    Protected Dim tr(thread)
    For i = 0 To thread - 1 : tr(i) = 0 : Next
    For i = 0 To thread - 1
      CopyStructure(@param, @dim_param(i), parametre)
      dim_param(i)\thread_pos = i
      dim_param(i)\thread_max = thread
      While tr(i) = 0 : tr(i) = CreateThread(proc, @dim_param(i)) : Delay(1) : Wend
    Next
    For i = 0 To thread - 1 : If IsThread(tr(i)) > 0 : WaitThread(tr(i)) : EndIf : Next
    FreeArray(tr())
  EndProcedure
  
  ;----------------------------------------------------------
  ; Test si l'image source est la même que l'image cible.  
  ; Pas nécessaire pour la plupart des filtres, mais évite des bugs graphiques en multithread lorsque plusieurs filtres sont appliqués consécutivement.
  Procedure Filter_BufferPrepare(*param.parametre)
    If *param\source = 0 Or *param\cible = 0 : ProcedureReturn 0: EndIf
    *param\tempo = 0
    If *param\source <> *param\cible
      *param\addr[0] = *param\source
    Else
      *param\tempo = AllocateMemory(*param\lg * *param\ht * 4)
      If Not *param\tempo : ProcedureReturn 0 : EndIf
      CopyMemory(*param\source , *param\tempo , *param\lg * *param\ht * 4)
      *param\addr[0] = *param\tempo
    EndIf
    *param\addr[1] = *param\cible
    ProcedureReturn 1
  EndProcedure
  
  ; ---
  
  Macro macro_Filter_BufferFinalize(opt)
    If *param\mask And *param\option[opt] : *param\mask_type = *param\option[opt] - 1 : MultiThread_MT(@_mask()) : EndIf
    If *param\tempo : FreeMemory(*param\tempo) : EndIf
  EndMacro
  
  ;-------------------------------------------------------------------
  Macro macro_calul_tread(lenght)
    Protected thread_start, thread_stop
    thread_start = (lenght * *param\thread_pos) / *param\thread_max
    thread_stop  = (lenght * (*param\thread_pos + 1)) / *param\thread_max
    If thread_stop > lenght : thread_stop = lenght - 1: EndIf
  EndMacro
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
  
  
  
  ;--
  Procedure Clear_Data_Filter(*p.parametre)
    *p\source = 0
    *p\cible = 0
    *p\mask = 0
    *p\lg.l = 0
    *p\ht.l = 0
    *p\thread_max = 0
    *p\thread_pos = 0
    *p\mask_type = 0
    *p\info_active = 0
    *p\typ = 0
    *p\name = ""
    *p\remarque = ""
    For i = 0 To 10
      *p\convolution3[i] = 0
      *p\addr[i] = 0
      *p\option[i] = 0
      *p\info[i] =""
      *p\info_data(i,0) = 0
      *p\info_data(i,1) = 0
      *p\info_data(i,2) = 0
    Next
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
  
  Procedure dither_grascale(*p.parametre)
    Protected *source = *p\source
    Protected *cible = *p\cible
    Protected total = *p\lg * *p\ht
    Protected *srcPixel.Pixel32, *dstPixel.Pixel32, r, g, b
    Protected startPos = (*p\thread_pos * total) / *p\thread_max
    Protected endPos   = ((*p\thread_pos + 1) * total) / *p\thread_max
    If endPos >= total : endPos = total - 1 :EndIf
    For i = startPos To endPos
      *srcPixel = *source + (i << 2)
      *dstPixel = *cible  + (i << 2)
      getrgb(*srcPixel\l , r , g , b)
      *dstPixel\l = ((r * 54 + g * 183 + b * 18) >> 8) * $10101
    Next
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
    
    Protected *source = *param\source
    Protected *cible  = *param\cible
    Protected *mask   = *param\mask
    Protected lg = *param\lg, ht = *param\ht
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
  Procedure _mask(*p.parametre)
    If *p\source_mask = 0 Or *p\cible = 0 Or *p\mask = 0 : ProcedureReturn : EndIf
    Protected i, a.l, r.l, g.l, b.l
    Protected a1.l, r1.l, g1.l, b1.l, maskVal.l, maskVal_inv.l
    Protected x, y, maskX, maskY, maskIndex
    Protected lg     = *p\lg
    Protected ht     = *p\ht
    Protected lgMask = *p\lg_mask
    Protected htMask = *p\ht_mask
    Protected ratioX.f = lgMask / lg
    Protected ratioY.f = htMask / ht
    Protected *srcPixel.Pixel32
    Protected *dstPixel.Pixel32
    Protected *makPixel.Pixel32
    Protected totalPixels = lg * ht
    Protected startPos = (*p\thread_pos * totalPixels) / *p\thread_max
    Protected endPos   = ((*p\thread_pos + 1) * totalPixels) / *p\thread_max
    ; calcul initial x,y
    x = startPos % lg
    y = startPos / lg
    For i = startPos To endPos - 1
      ; Coordonnées correspondantes dans le masque
      maskX = Int(x * ratioX)
      maskY = Int(y * ratioY)
      maskIndex = (maskY * lgMask + maskX) << 2
      *srcPixel = *p\source_mask + (i << 2)
      *dstPixel = *p\cible       + (i << 2)
      *makPixel = *p\mask        + maskIndex
      maskVal     = *makPixel\l & $FF
      maskVal_inv = 255 - maskVal
      If *p\mask_type = 1
        If maskVal < 127 : *dstPixel\l = *srcPixel\l : EndIf
      Else
        getargb(*srcPixel\l, a1, r1, g1, b1)
        getargb(*dstPixel\l, a , r , g , b )
        a = ((a  * maskVal + a1 * maskVal_inv) >> 8)
        r = ((r  * maskVal + r1 * maskVal_inv) >> 8)
        g = ((g  * maskVal + g1 * maskVal_inv) >> 8)
        b = ((b  * maskVal + b1 * maskVal_inv) >> 8)
        *dstPixel\l = (a << 24) | (r << 16) | (g << 8) | b
      EndIf
      ; -------- mise à jour optimisée x,y --------
      x + 1
      If x = lg : x = 0 : y + 1 : EndIf
    Next
  EndProcedure
  
  ;-------------------------------------------------------------------
  Macro filter_start(name , opt , mt = 0)
    
    If *param\source = 0 Or *param\cible = 0 : ProcedureReturn : EndIf
    Protected *tempo = 0
    If *param\source <> *param\cible
      *param\addr[0] = *param\source
      *param\addr[1] = *param\cible
    Else
      *tempo = AllocateMemory(*param\lg * *param\ht * 4)
      If Not *tempo : ProcedureReturn : EndIf
      CopyMemory(*param\source , *tempo , *param\lg * *param\ht * 4)
      *param\addr[0] = *tempo
      *param\addr[1] = *param\cible    
    EndIf
    MultiThread_MT(name,mt)
    If *param\mask And *param\option[opt] : *param\mask_type = *param\option[opt] - 1 : MultiThread_MT(@_mask()) : EndIf
    If *tempo : FreeMemory(*tempo) : EndIf
    
  EndMacro
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
          i = ((y*lg)+x)*3
          r=PeekA(temps_p + i + 2 + dif1)
          g=PeekA(temps_p + i + 1 + dif1)
          b=PeekA(temps_p + i + 0 + dif1)
          PokeL(nom_p + ((y * lg)+ x)*4 , (r << 16) + (g << 8) + b)
        Next
        dif1 = dif1 + dif
      Next
      FreeImage(temps) ; supprime l'image 24bits
    EndIf
    ProcedureReturn 1
  EndProcedure
 
  
  ;-------------------------------------------------------------------
  Procedure get_info(filter)
    ;If tabfunc(list_filtre_selected()\id) <> 0 : CallFunctionFast(tabfunc(list_filtre_selected()\id),param) : EndIf
  EndProcedure
  
  Procedure Set_Cible(image)
    If IsImage(image) And StartDrawing(ImageOutput(image))
      param\cible = DrawingBuffer()
      param\lg = ImageWidth(image)
      param\ht = ImageHeight(image)
      StopDrawing()
    EndIf
  EndProcedure
  
  Procedure Set_Source(image)
    If IsImage(image) And StartDrawing(ImageOutput(image))
      param\source = DrawingBuffer()
      param\lg = ImageWidth(image)
      param\ht = ImageHeight(image)
      StopDrawing()
    EndIf
  EndProcedure
  
  Procedure Set_Mask(image)
    If IsImage(image) And StartDrawing(ImageOutput(image))
      param\mask = DrawingBuffer()
      param\lg_mask = ImageWidth(image)
      param\ht_mask = ImageHeight(image)
      StopDrawing()
    EndIf
  EndProcedure
  
  Procedure Set_Mix(image)
    If IsImage(image) And StartDrawing(ImageOutput(image))
      param\mix = DrawingBuffer()
      param\lg_mix = ImageWidth(image)
      param\ht_mix = ImageHeight(image)
      StopDrawing()
    EndIf
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
  
  Global *Asm_Memory_All = AllocateMemory((8*8 + 16*16)*128)
  
  Procedure Push_Reg(*param.parametre)
    Protected *pos = *Asm_Memory_All + (*param\thread_pos * 320)
    !mov rax,[p.p_pos]
    ; Registres généraux (64 octets)
    !mov [rax + 0*8], rbx
    !mov [rax + 1*8], r9
    !mov [rax + 2*8], r10
    !mov [rax + 3*8], r11
    !mov [rax + 4*8], r12
    !mov [rax + 5*8], r13
    !mov [rax + 6*8], r14
    !mov [rax + 7*8], r15
    ; Registres XMM (256 octets)
    !movdqu [rax + 64 + 0*16], xmm0
    !movdqu [rax + 64 + 1*16], xmm1
    !movdqu [rax + 64 + 2*16], xmm2
    !movdqu [rax + 64 + 3*16], xmm3
    !movdqu [rax + 64 + 4*16], xmm4
    !movdqu [rax + 64 + 5*16], xmm5
    !movdqu [rax + 64 + 6*16], xmm6
    !movdqu [rax + 64 + 7*16], xmm7
    !movdqu [rax + 64 + 8*16], xmm8
    !movdqu [rax + 64 + 9*16], xmm9
    !movdqu [rax + 64 + 10*16], xmm10
    !movdqu [rax + 64 + 11*16], xmm11
    !movdqu [rax + 64 + 12*16], xmm12
    !movdqu [rax + 64 + 13*16], xmm13
    !movdqu [rax + 64 + 14*16], xmm14
    !movdqu [rax + 64 + 15*16], xmm15
  EndProcedure
  
  Procedure Pop_reg(*param.parametre)
    Protected *pos = *Asm_Memory_All + (*param\thread_pos * 320)
    !mov rax,[p.p_pos]
    ; Registres généraux
    !mov rbx, [rax + 0*8]
    !mov r9,  [rax + 1*8]
    !mov r10, [rax + 2*8]
    !mov r11, [rax + 3*8]
    !mov r12, [rax + 4*8]
    !mov r13, [rax + 5*8]
    !mov r14, [rax + 6*8]
    !mov r15, [rax + 7*8]
    ; Registres XMM
    !movdqu xmm0,  [rax + 64 + 0*16]
    !movdqu xmm1,  [rax + 64 + 1*16]
    !movdqu xmm2,  [rax + 64 + 2*16]
    !movdqu xmm3,  [rax + 64 + 3*16]
    !movdqu xmm4,  [rax + 64 + 4*16]
    !movdqu xmm5,  [rax + 64 + 5*16]
    !movdqu xmm6,  [rax + 64 + 6*16]
    !movdqu xmm7,  [rax + 64 + 7*16]
    !movdqu xmm8,  [rax + 64 + 8*16]
    !movdqu xmm9,  [rax + 64 + 9*16]
    !movdqu xmm10, [rax + 64 + 10*16]
    !movdqu xmm11, [rax + 64 + 11*16]
    !movdqu xmm12, [rax + 64 + 12*16]
    !movdqu xmm13, [rax + 64 + 13*16]
    !movdqu xmm14, [rax + 64 + 14*16]
    !movdqu xmm15, [rax + 64 + 15*16]
  EndProcedure
  
  ;-------------------------------------------------------------------
  
  ;-- IncludeFile
  EnableExplicit 
  ;-- Blur
  IncludePath "filtres\blur\"
  
  ;#Blur_Classic
  XIncludeFile "blur_box.pbi"
  XIncludeFile "blur_box_Guillossien.pbi"
  XIncludeFile "blur_IIR.pbi"
  XIncludeFile "stackblur.pbi"
  XIncludeFile "CircularMeanblur2.pbi"
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
  ; #Dither_Hybrid - Méthodes hybrides/space-filling curves
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
  
  
  
  IncludePath "filtres\texture\"
  XIncludeFile "Mosaic.pbi"
  XIncludeFile "HexMosaic.pbi"
  XIncludeFile "IrregularHexMosaic.pbi"
  XIncludeFile "Diffuse.pbi"
  XIncludeFile "Glitch.pbi"
  XIncludeFile "Kaleidoscope.pbi"
  XIncludeFile "Emboss_bump.pbi"
  ;XIncludeFile "fx\mettalic_effect.pbi"
  
  
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
  
  IncludePath "filtres\texture2\"
  XIncludeFile "texture_synthesis.pbi"
  
  
  ;XIncludeFile "Convolution\Convol3x3.pbi"
  
  IncludePath "filtres\Color_Space\"
  XIncludeFile "RgbToYuv.pbi"
  XIncludeFile "YUVtoRGB.pbi"
  XIncludeFile "RGB_YUV_Modif.pbi"
  XIncludeFile "RGBtoYIQ.pbi"
  XIncludeFile "YIQtoRGB.pbi"
  XIncludeFile "RGB_YIQ_Modif.pbi"
  XIncludeFile "RGBtoLAB.pbi"
  XIncludeFile "RGB_LAB_Modif.pbi"
  
  IncludePath "filtres\mix\"
  XIncludeFile "mix.pbi"
  
  IncludePath "filtres\other\"
  XIncludeFile "fire.pbi"
    
EndModule

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 635
; FirstLine = 601
; Folding = ---------
; Optimizer
; EnableXP
; DPIAware
; CPU = 5
; DisableDebugger
; Compiler = PureBasic 6.21 (Windows - x64)