Procedure LaplacianPyramidSharpen_ScaleImage(*src, oldW, oldH, *dst, newW, newH)
  Protected x,y,sx,sy
  Protected fx.f, fy.f, dx, dy
  Protected px00, px01, px10, px11
  Protected r,g,b,a
  Protected v,v1

  For y = 0 To newH-1
    fy = Bool(newH>1) * (y*(oldH-1)/(newH-1))
    sy = Int(fy) : dy = fy-sy

    For x = 0 To newW-1
      fx = Bool(newW>1) * (x*(oldW-1)/(newW-1))
      sx = Int(fx) : dx = fx-sx

      CLAMP(sx,0,oldW-1)
      CLAMP(sy,0,oldH-1)
      v = sx+1 : CLAMP(v,0,oldW-1)
      v1 = sy+1 : CLAMP(v1,0,oldH-1)

      px00 = PeekL(*src + ((sy*oldW + sx)*4))
      px01 = PeekL(*src + ((sy*oldW + v )*4))
      px10 = PeekL(*src + ((v1*oldW + sx)*4))
      px11 = PeekL(*src + ((v1*oldW + v )*4))

      r = ((px00>>16&255)*(1-dx)*(1-dy)+(px01>>16&255)*dx*(1-dy)+(px10>>16&255)*(1-dx)*dy+(px11>>16&255)*dx*dy)
      g = ((px00>>8 &255)*(1-dx)*(1-dy)+(px01>>8 &255)*dx*(1-dy)+(px10>>8 &255)*(1-dx)*dy+(px11>>8 &255)*dx*dy)
      b = ((px00    &255)*(1-dx)*(1-dy)+(px01    &255)*dx*(1-dy)+(px10    &255)*(1-dx)*dy+(px11    &255)*dx*dy)
      a = ((px00>>24&255)*(1-dx)*(1-dy)+(px01>>24&255)*dx*(1-dy)+(px10>>24&255)*(1-dx)*dy+(px11>>24&255)*dx*dy)

      PokeL(*dst + ((y*newW+x)*4),(a<<24)|(r<<16)|(g<<8)|b)
    Next
  Next
EndProcedure

Macro LaplacianPyramidSharpen_UpscaleImage(src,w,h,dst,nw,nh)
  LaplacianPyramidSharpen_ScaleImage(src,w,h,dst,nw,nh)
EndMacro

Procedure LaplacianPyramidSharpen_BlurBuffer(*buf,w,h,radius)
  If radius<1 : ProcedureReturn : EndIf
  Protected *tmp=AllocateMemory(w*h*4)
  Protected x,y,i,px,idx,sr,sg,sb,sa,c

  For y=0 To h-1
    For x=0 To w-1
      sr=0:sg=0:sb=0:sa=0:c=0
      For i=-radius To radius
        px=x+i : CLAMP(px,0,w-1)
        idx=(y*w+px)*4
        sa+PeekA(*buf+idx+3)
        sr+PeekA(*buf+idx+2)
        sg+PeekA(*buf+idx+1)
        sb+PeekA(*buf+idx)
        c+1
      Next
      idx=(y*w+x)*4
      PokeA(*tmp+idx+3,sa/c)
      PokeA(*tmp+idx+2,sr/c)
      PokeA(*tmp+idx+1,sg/c)
      PokeA(*tmp+idx  ,sb/c)
    Next
  Next

  For x=0 To w-1
    For y=0 To h-1
      sr=0:sg=0:sb=0:sa=0:c=0
      For i=-radius To radius
        px=y+i : CLAMP(px,0,h-1)
        idx=(px*w+x)*4
        sa+PeekA(*tmp+idx+3)
        sr+PeekA(*tmp+idx+2)
        sg+PeekA(*tmp+idx+1)
        sb+PeekA(*tmp+idx)
        c+1
      Next
      idx=(y*w+x)*4
      PokeA(*buf+idx+3,sa/c)
      PokeA(*buf+idx+2,sr/c)
      PokeA(*buf+idx+1,sg/c)
      PokeA(*buf+idx  ,sb/c)
    Next
  Next
  FreeMemory(*tmp)
EndProcedure

Procedure LaplacianPyramidSharpen_spEx(*FilterCtx.FilterParams)
  With *FilterCtx
    Protected lg = \image_lg[0], ht = \image_ht[1]
    Protected levels = \option[0]
    Protected kernel = \option[1]
    Protected gain.f = \option[2] / 100.0
    Protected gain2 
    If levels<1:levels=1:EndIf
    If kernel<0:kernel=0:EndIf

    Protected l,i
    Protected *temp=AllocateMemory(lg*ht*4)

    Dim pyramid.i(levels-1)
    Dim laplacian_tab.i(levels-2)

    For l=0 To levels-1
      pyramid(l)=AllocateMemory((lg>>l)*(ht>>l)*4)
    Next
    For l=0 To levels-2
      laplacian_tab(l)=AllocateMemory((lg>>l)*(ht>>l)*4)
    Next

    LaplacianPyramidSharpen_ScaleImage(\addr[0],lg,ht,pyramid(0),lg,ht)
    For l=1 To levels-1
      LaplacianPyramidSharpen_ScaleImage(pyramid(l-1),lg>>(l-1),ht>>(l-1),pyramid(l),lg>>l,ht>>l)
    Next

    For l=0 To levels-2
      LaplacianPyramidSharpen_UpscaleImage(pyramid(l+1),lg>>(l+1),ht>>(l+1),*temp,lg>>l,ht>>l)
      For i=0 To (lg>>l)*(ht>>l)-1
        PokeL(laplacian_tab(l)+i*4,PeekL(pyramid(l)+i*4)-PeekL(*temp+i*4))
      Next
    Next

    For l=0 To levels-1
      LaplacianPyramidSharpen_BlurBuffer(pyramid(l),lg>>l,ht>>l,kernel)
    Next

    For l=levels-2 To 0 Step -1
      LaplacianPyramidSharpen_UpscaleImage(pyramid(l+1),lg>>(l+1),ht>>(l+1),*temp,lg>>l,ht>>l)
      gain2 = gain
      For i=0 To (lg>>l)*(ht>>l)-1
        Protected a,r,g,b
        a=(PeekL(*temp+i*4)>>24 & 255)+gain2 *(PeekL(laplacian_tab(l)+i*4)>>24 & 255)
        r=(PeekL(*temp+i*4)>>16 & 255)+gain2 *(PeekL(laplacian_tab(l)+i*4)>>16 & 255)
        g=(PeekL(*temp+i*4)>>8 & 255)+gain2 *(PeekL(laplacian_tab(l)+i*4)>>8 & 255)
        b=(PeekL(*temp+i*4)    & 255)+gain2 *(PeekL(laplacian_tab(l)+i*4)    & 255)
        Clamp(a,0,255):Clamp(r,0,255):Clamp(g,0,255):Clamp(b,0,255)
        PokeL(pyramid(l)+i*4,(a<<24)|(r<<16)|(g<<8)|b)
      Next
    Next

    CopyMemory(pyramid(0),\addr[1],lg*ht*4)

    For l=0 To levels-1
      FreeMemory(pyramid(l))
      If l<levels-1:FreeMemory(laplacian_tab(l)):EndIf
    Next
    FreeMemory(*temp)
  EndWith
EndProcedure

Procedure LaplacianPyramidSharpenEx(*FilterCtx.FilterParams)
  Restore LaplacianPyramidSharpen_data
  Protected last_data = Filter_InitAndValidate()
  If last_data < 0 : ProcedureReturn 0 : EndIf
  
  LaplacianPyramidSharpen_spEx(*FilterCtx)
  
  mask_update(*FilterCtx, last_data)
EndProcedure

Procedure LaplacianPyramidSharpen(source , cible , mask , niveaux , kernel , gain)
  Set_Source(source)
  Set_Cible(cible)
  Set_Mask(mask)
  With FilterCtx
    \option[0] = niveaux
    \option[1] = kernel
    \option[2] = gain
  EndWith
  LaplacianPyramidSharpenEx(FilterCtx.FilterParams)
EndProcedure

DataSection
  LaplacianPyramidSharpen_data:
  Data.s "LaplacianPyramidSharpen"
  Data.s "Accentuation par pyramide laplacienne"
  Data.i #FilterType_EdgeDetection
  Data.i #EdgeDetect_MultiScale
  
  Data.s "Niveaux"
  Data.i 1,6,3
  Data.s "Kernel"
  Data.i 0,10,2
  Data.s "Gain %"
  Data.i 50,300,100
  Data.s "XXX"
EndDataSection
; IDE Options = PureBasic 6.40 (Windows - x64)
; CursorPosition = 168
; FirstLine = 135
; Folding = --
; EnableXP
; DPIAware