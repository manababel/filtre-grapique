; ---------------------------------------------------
; TurbulenceBlur
; Déplacement par turbulence (fBm) — ARGB32
; Structure compatible : mon_prog / mon_prog_MT
; Paramètres :
; option[0] = amount (px, entier, ex: 20)
; option[1] = scale  (échelle fréquence base, entier>0, ex: 32 -> plus petit = plus détaillé)
; option[2] = octaves (1..8)
; option[3] = seed    (entier)
; option[4] = mask (0=no,1=yes; mask dans addr[2])
; ---------------------------------------------------

; --- Hash pseudo-aléatoire 32-bit -> signed 16-bit
Macro TB_hash(ix,iy,seed, out)
  ; simple int32 hash (mix)
  n = ix * 374761393 + iy * 668265263 + seed * 2246822519
  n = n ~ (n >> 13)
  n = n * 1274126177
  out = (n & $FFFF) - $8000   ; résultat dans [-32768 .. 32767]
EndMacro

; --- Value noise bilinéaire sample at integer lattice with fixed-point frac (fraction 0..255)
; input: fx = x coordinate fixed-point (8 fractional bits), fy likewise
; frequency controlled by 'freq' (fixed-point scale factor): here fx_in/freq -> lattice coords
; returns signed 16-bit noise scaled to [-256..256] in variable 'nv' (8-bit scaled)
Macro TB_noise_bilerp(fx, fy, freq, seed, nv)
  ; compute u = fx / freq  in fixed-point (8 fractional)
  u = fx * 256 / freq      ; now u in 8.8 fixed (integer)
  v = fy * 256 / freq
  ix = u >> 8     ; integer lattice x
  iy = v >> 8     ; integer lattice y
  fx_frac = u & $FF
  fy_frac = v & $FF

  ; sample four lattice corners
  TB_hash(ix,   iy,   seed, h00)
  TB_hash(ix+1, iy,   seed, h10)
  TB_hash(ix,   iy+1, seed, h01)
  TB_hash(ix+1, iy+1, seed, h11)

  ; map hash 16-bit -> signed in -256..+256 range (approx)
  ; hXX in [-32768..32767] -> n = hXX >> 7 gives ~[-256..255]
  n00 = h00 >> 7
  n10 = h10 >> 7
  n01 = h01 >> 7
  n11 = h11 >> 7

  ; bilinear interpolation with 8-bit fractional parts
  ; interp x
  t0 = ((n00 * (256 - fx_frac)) + (n10 * fx_frac)) >> 8    ; result ~[-256..256]
  t1 = ((n01 * (256 - fx_frac)) + (n11 * fx_frac)) >> 8
  ; interp y
  nv = ((t0 * (256 - fy_frac)) + (t1 * fy_frac)) >> 8
EndMacro

; --- fBm turbulence : sum octaves of |noise| * amplitude
; inputs: x,y in integer pixel coords (not fixed), amount in px, scale base (freq), octaves, seed
; outputs: dx_fixed, dy_fixed (fixed-point with 8-bit frac)
Macro TB_turbulence_at(x, y, amount, scale, octaves, seed, dx_fixed, dy_fixed)
  ; We'll compute two independent turbulence channels using different seeds
  ; fixed point: displacements in pixels * 256
  accx = 0 : accy = 0
  amp = amount * 256      ; initial amplitude in fixed-point
  freq = scale            ; freq expressed as "pixels per lattice" (integer >0)

  For o = 0 To octaves - 1
    ; sample noise at current freq: use fx/fy as fixed-point with 8 fractional bits
    fx = (x << 8)        ; x * 256
    fy = (y << 8)
    ; increase frequency by factor 2 each octave: use freq_scaled = freq >> o  (so octave doubles detail)
    ; but avoid shifting to 0:
    fscale = freq >> o
    If fscale < 1 Then fscale = 1 : EndIf

    TB_noise_bilerp(fx, fy, fscale, seed + o*131, nvx) ; nvx in approx [-256..256]
    TB_noise_bilerp(fx + 12345, fy + 67890, fscale, seed + o*131 + 777, nvy) ; offset for y-channel

    ; use absolute to produce turbulence-like (ridged) effect -> abs(nv)
    If nvx < 0 Then nvx = -nvx : EndIf
    If nvy < 0 Then nvy = -nvy : EndIf

    ; accumulate weighted by amplitude (amp is fixed-point px*256)
    ; nvx ~ 0..256 -> convert to displacement: (nvx/256)*amp/256 => (nvx * amp) >> 16
    accx = accx + ((nvx * amp) >> 16)
    accy = accy + ((nvy * amp) >> 16)

    ; next octave: half amplitude, double frequency (we did freq via shift)
    amp = amp >> 1
  Next

  dx_fixed = accx    ; fixed-point px*256
  dy_fixed = accy
EndMacro

; --- Bilinear sample source at fixed-point coords sx_fixed, sy_fixed (8-bit frac)
; outputs a1..b1 8-bit channels
Macro TB_bilinear_sample(src32_ptr, sx_fixed, sy_fixed, a1, r1, g1, b1)
  ix = sx_fixed >> 8
  iy = sy_fixed >> 8
  fx = sx_fixed & $FF
  fy = sy_fixed & $FF

  ; clamp coordinates for edge sampling (border replicate)
  If ix < 0 Then ix = 0 : EndIf
  If iy < 0 Then iy = 0 : EndIf
  If ix >= w - 1 Then ix = w - 1 : fx = 0 : EndIf
  If iy >= h - 1 Then iy = h - 1 : fy = 0 : EndIf

  p00 = src32_ptr + ((iy * w + ix) * 4)
  p10 = p00 + 4
  p01 = src32_ptr + (((iy+1) * w + ix) * 4)
  p11 = p01 + 4

  a00 = (p00\l >> 24) & $FF : r00 = (p00\l >> 16) & $FF : g00 = (p00\l >> 8) & $FF : b00 = p00\l & $FF
  a10 = (p10\l >> 24) & $FF : r10 = (p10\l >> 16) & $FF : g10 = (p10\l >> 8) & $FF : b10 = p10\l & $FF
  a01 = (p01\l >> 24) & $FF : r01 = (p01\l >> 16) & $FF : g01 = (p01\l >> 8) & $FF : b01 = p01\l & $FF
  a11 = (p11\l >> 24) & $FF : r11 = (p11\l >> 16) & $FF : g11 = (p11\l >> 8) & $FF : b11 = p11\l & $FF

  ; interpolate horizontally (8-bit frac)
  a0 = ((a00 * (256 - fx)) + (a10 * fx)) >> 8
  r0 = ((r00 * (256 - fx)) + (r10 * fx)) >> 8
  g0 = ((g00 * (256 - fx)) + (g10 * fx)) >> 8
  b0 = ((b00 * (256 - fx)) + (b10 * fx)) >> 8

  a1b = ((a01 * (256 - fx)) + (a11 * fx)) >> 8
  r1b = ((r01 * (256 - fx)) + (r11 * fx)) >> 8
  g1b = ((g01 * (256 - fx)) + (g11 * fx)) >> 8
  b1b = ((b01 * (256 - fx)) + (b11 * fx)) >> 8

  ; interpolate vertical
  a1 = ((a0 * (256 - fy)) + (a1b * fy)) >> 8
  r1 = ((r0 * (256 - fy)) + (r1b * fy)) >> 8
  g1 = ((g0 * (256 - fy)) + (g1b * fy)) >> 8
  b1 = ((b0 * (256 - fy)) + (b1b * fy)) >> 8
EndMacro

; ---------------------------------------------------
; mon_prog_MT : thread worker
; ---------------------------------------------------
Procedure TurbulenceBlur_MT(*param.parametre)
  Protected w = *param\lg, h = *param\ht
  Protected *src32.pixel32 = *param\addr[0]
  Protected *dst32.pixel32 = *param\addr[1]
  Protected *mask32.pixel32 = 0
  Protected has_mask = 0

  Protected amount = *param\option[0]       ; pixels
  Protected scale  = *param\option[1]       ; base frequency control (pixels per lattice)
  Protected octaves = *param\option[2]
  Protected seed   = *param\option[3]

  If octaves < 1 Then octaves = 1 : EndIf
  If octaves > 8 Then octaves = 8 : EndIf
  If scale < 1 Then scale = 1 : EndIf

  ; mask
  If *param\option[4] <> 0
    mask_ptr = *param\addr[2]
    If mask_ptr <> 0
      mask32 = mask_ptr
      has_mask = 1
    EndIf
  EndIf

  ; découpage en threads (détermine thread_start, thread_stop)
  macro_calul_tread(h)

  ; parcourir lignes assignées
  For y = thread_start To thread_stop - 1
    base = y * w
    For x = 0 To w - 1
      pos = base + x

      ; respect mask
      If has_mask
        If (mask32 + pos*4)\l = 0
          ProcedureContinue
        EndIf
      EndIf

      ; compute turbulence displacement at integer (x,y)
      TB_turbulence_at(x, y, amount, scale, octaves, seed, dx_fixed, dy_fixed)
      ; dx_fixed/dy_fixed are px*256 (fixed)
      ; sample source at (x + dx, y + dy)
      sx_fixed = (x << 8) + dx_fixed
      sy_fixed = (y << 8) + dy_fixed

      ; bilinear sample
      TB_bilinear_sample(src32, sx_fixed, sy_fixed, As, rS, gS, bS)

      ; write to dst
      dstpix = dst32 + pos*4
      dstpix\l = ( (As & $FF) << 24 ) + ( (rS & $FF) << 16 ) + ( (gS & $FF) << 8 ) + (bS & $FF)
    Next
  Next
EndProcedure

; ---------------------------------------------------
; mon_prog : entrée principale
; ---------------------------------------------------
Procedure TurbulenceBlur(*param.parametre)
  If param\info_active
    param\typ      = #FilterType_Blur
    param\subtype  = #Blur_Classic
    param\name     = "TurbulenceBlur"
    param\remarque = "Flou par turbulence (déformation par fBm) — ARGB32"
    param\info[0]  = "Amount (px)"        ; option[0]
    param\info[1]  = "Scale (pixels)"     ; option[1]
    param\info[2]  = "Octaves"            ; option[2]
    param\info[3]  = "Seed"               ; option[3]
    param\info[4]  = "Masque (0/1)"      ; option[4]
    param\info_data(0,0)=0  : param\info_data(0,1)=200 : param\info_data(0,2)=20
    param\info_data(1,0)=1  : param\info_data(1,1)=256 : param\info_data(1,2)=32
    param\info_data(2,0)=1  : param\info_data(2,1)=8   : param\info_data(2,2)=3
    param\info_data(3,0)=0  : param\info_data(3,1)=65535: param\info_data(3,2)=1234
    param\info_data(4,0)=0  : param\info_data(4,1)=1   : param\info_data(4,2)=0
    ProcedureReturn
  EndIf

  ; Préparer buffers et copier source -> dest (on écrira sur dst)
  If Filter_BufferPrepare(*param.parametre) <> 0
    CopyMemory(*param\addr[0], *param\addr[1], (*param\lg * *param\ht * 4))
    MultiThread_MT(@TurbulenceBlur_MT())
    macro_Filter_BufferFinalize(3)
  EndIf
EndProcedure

; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 139
; FirstLine = 133
; Folding = --
; EnableXP
; DPIAware