; limiter affichage logo sur 200 lignes

; coder le scrolling
;  font = 320*256
;  1 caractere = 32*32
; 	Y scrolling = 164


; OK - deplacement du logo : en X de 0 à 1920 par pas de 16
;						en Y , zone de 103 lignes de vide, 314 lignes de logo. la pos Y varie de 0 a 239 => 
;								pos Y debut lecture logo = pos Y - 103 // si négatif on lit le logo a partir de 0 sur hauteur = 198- (-( pos Y -103 ))
;																			si positif, on lit le logo a partir de (pos Y -103) sur 314-

;			determiner : pos Y debut lecture du logo, hauteur du logo

; 344 / 320 + 12+ 12 => 3*4 +320 +3*4
; 200 lignes
; seven gates of jambala 5 = OK

; conversion couleurs ST vers CRY ??? ST=>24 bits=>CRY : de 0 à 7 => 256/8=32

; barres de couleur : ripper la table !!!
;		- bitmap Object list qui n'avance pas, reste sur le meme graph / pitch =0   / une barre = 4*2 octets CRY

; - logo se promenant sur tout l'ecran = bitmap dans object list, modifié par gpu


; - barres a droite et a gauche en fonction du volume du son YM : sprite debut toujours le meme, position Y sur l'ecran en fonction du volume ( 1/16eme de 200 lignes) , hauteur =200-position Y
; - scrolling en bas  : 190 a 221 = 32 de haut


;------------------
; total des sprites
; 200 lignes de rasters =======> essayer avec 1 seul sprite de 200 lignes !!!
; + 1 = sprite logo plein ecran
; + 1 = zone de scrolling texte
; + 6 = barres equalizeur sur les cotés
; = 208 sprites


;;------------------
; OL+48 = debut des sprites
; phrase = 8 octets : table de couleur 8 octets par ligne
;



	include	"jaguar.inc"

rasters						.equ		1
increment_en_X_logo			.equ		13			; normal=13 
increment_en_Y_logo			.equ		2			; normal=2

premiere_ligne_a_l_ecran	.equ		49


nb_actuel_de_couleurs		.equ		19+40+109
logo_X_maximal				.equ		1920
logo_Y_maximal				.equ		240
logo_replicants__nb_lignes_vide_au_dessus	.equ		102
largeur_logo_replicants_en_octets			.equ		2240

GPU_STACK_SIZE	equ		32	; long words
GPU_USP			equ		(G_ENDRAM-(4*GPU_STACK_SIZE))
GPU_ISP			equ		(GPU_USP-(4*GPU_STACK_SIZE))


ob_list_courante			equ		((ENDRAM-$4000)+$2000)				; address of read list
nb_octets_par_ligne			equ		640

ob_list_1				equ		(ENDRAM-52000)				; address of read list =  
ob_list_2				equ		(ENDRAM-104000)				; address of read list =  



.opt "~Oall"

.text

			.68000


	move.l		#$70007,G_END
	move.l		#$70007,D_END
	

	move.l		#INITSTACK-128, sp	
	;move.w		#%0000011011000001, VMODE			; 320x256 / CRY / $6C7
	move.w		#%0000011011000111, VMODE			; 320x256 / RGB / pwidth = 011 = 3 320x256
	;move.w		#%0000010011000111, VMODE			; 320x256 / RGB / pwidth = 01 = 2 => ca divise par 3 :  320x256
	
	
	move.w		#$100,JOYSTICK

; clear BSS
	lea			DEBUT_BSS,a0
	lea			FIN_RAM,a1
	moveq		#0,d0
	
boucle_clean_BSS:
	move.b		d0,(a0)+
	cmp.l		a0,a1
	bne.s		boucle_clean_BSS
; clear stack
	lea			INITSTACK-100,a0
	lea			INITSTACK,a1
	moveq		#0,d0
	
boucle_clean_BSS2:
	move.b		d0,(a0)+
	cmp.l		a0,a1
	bne.s		boucle_clean_BSS2

; copie du code GPU
	move.l	#0,G_CTRL
; copie du code GPU dans la RAM GPU

	lea		GPU_debut,A0
	lea		G_RAM,A1
	move.l	#GPU_fin-GPU_base_memoire,d0
	lsr.l	#2,d0
	sub.l	#1,D0
boucle_copie_bloc_GPU:
	move.l	(A0)+,(A1)+
	dbf		D0,boucle_copie_bloc_GPU



    bsr   		  InitVideo               	; Setup our video registers.

; creer les object listes
	lea		ob_list_1,a6
	bsr		preparation_OL
	lea		ob_list_2,a6
	bsr		preparation_OL



	move.w		#801,VI			; stop VI

	bsr			creation_table_rasters

; init CLUT

	lea			CLUT+2,a1
	lea			CLUT_RGB,a0
	move.w		#nb_actuel_de_couleurs-1,d0
copie_clut:
	move.w		(a0)+,(a1)+
	dbf			d0,copie_clut

	

; launch GPU

	move.l	#REGPAGE,G_FLAGS
	move.l	#GPU_init,G_PC
	move.l  #RISCGO,G_CTRL	; START GPU


    ;bsr     copy_olist              	; use Blitter to update active list from shadow

	;move.l	#ob_list_courante,d0					; set the object list pointer
	;swap	d0
	;move.l	d0,OLP

	move.l  #VBL,LEVEL0     	; Install 68K LEVEL0 handler
	move.w  a_vde,d0                	; Must be ODD
	sub.w   #16,d0
	ori.w   #1,d0
	move.w  d0,VI

	move.w  #%01,INT1                 	; Enable video interrupts 11101


	and.w   #%1111100011111111,sr				; 1111100011111111 => bits 8/9/10 = 0
	and.w   #$f8ff,sr






main:

	bra.s		main



;--------------------------
; VBL

VBL:
                movem.l d0-d7/a0-a6,-(a7)
				

                ;bsr     copy_olist              	; use Blitter to update active list from shadow

                addq.l	#1,vbl_counter

                ;move.w  #$101,INT1              	; Signal we're done
				move.w	#$101,INT1
                move.w  #$0,INT2
.exit:
                movem.l (a7)+,d0-d7/a0-a6
                rte


				.if		1=0
;----------------------------------
; recopie l'object list dans la courante

copy_olist:
				move.l	#ob_list_courante,A1_BASE			; = DEST
				move.l	#$0,A1_PIXEL
				move.l	#PIXEL16|XADDPHR|PITCH1,A1_FLAGS
				move.l	#ob_liste_originale,A2_BASE			; = source
				move.l	#$0,A2_PIXEL
				move.l	#PIXEL16|XADDPHR|PITCH1,A2_FLAGS
				move.w	#1,d0
				swap	d0
				move.l	#fin_ob_liste_originale-ob_liste_originale,d1
				move.w	d1,d0
				move.l	d0,B_COUNT
				move.l	#LFU_REPLACE|SRCEN,B_CMD
				rts
				.endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Procedure: InitVideo (same as in vidinit.s)
;;            Build values for hdb, hde, vdb, and vde and store them.
;;

largeur_bande_gauche		.equ		24+8+4+12+2		; 24
largeur_bande_droite		.equ		24	; 4*4

InitVideo:
                movem.l d0-d6,-(sp)

				
				move.w	#-1,ntsc_flag
				move.l	#50,_50ou60hertz
	
				move.w  CONFIG,d0                ; Also is joystick register
                andi.w  #VIDTYPE,d0              ; 0 = PAL, 1 = NTSC
                beq.s     .palvals
				move.w	#1,ntsc_flag
				move.l	#60,_50ou60hertz
	

.ntscvals:		move.w  #NTSC_HMID,d2
                move.w  #NTSC_WIDTH,d0

                move.w  #NTSC_VMID,d6
                move.w  #NTSC_HEIGHT,d4
				
                bra.s    calc_vals
.palvals:
				move.w #PAL_HMID,d2
				move.w #PAL_WIDTH,d0

				move.w #PAL_VMID,d6				
				move.w #PAL_HEIGHT,d4

				
calc_vals:		
                move.w  d0,width
                move.w  d4,height
                move.w  d0,d1
                asr     #1,d1                   ; Width/2
                sub.w   d1,d2                   ; Mid - Width/2
                add.w   #4,d2                   ; (Mid - Width/2)+4
				
				sub.w	#largeur_bande_gauche,d2
				
                sub.w   #1,d1                   ; Width/2 - 1
				
				add.w	#largeur_bande_droite,d1
                
				
				ori.w   #$400,d1                ; (Width/2 - 1)|$400  : 
				
				
				
                move.w  d1,a_hde
                move.w  d1,HDE
				;add.w	#2,d1
				;move.w	d1,HBB
				
                move.w  d2,a_hdb
                move.w  d2,HDB1
                move.w  d2,HDB2
                move.w  d6,d5
                sub.w   d4,d5
                add.w   #16,d5
                move.w  d5,a_vdb
                add.w   d4,d6
                move.w  d6,a_vde
			
			    move.w  a_vdb,VDB
				move.w  a_vde,VDE    

		moveq	#0,d0
		move.w	a_vdb,d0
		addq.l	#1,d0
		move.l	d0,GPU_premiere_ligne				; $24 en pal => 36 / ntsc : 26 / $1a

		moveq	#0,d0
		move.w	a_vde,d0
		addq.l	#1,d0
		subq.l	#2,d0
		move.l	d0,GPU_derniere_ligne				; $262 en pal => 305 / ntsc : $1FC / 508 => 254
		
		;move.w		#$6b1,HBB
		;move.w		#$7d,HBE
	
		;move.w		#$A0,HDB1
		;move.w		#$A0,HDB2
		;move.w		#$6BF,HDE
	
		
; force ntsc pour pal
		;move.l	#premiere_ligne_a_l_ecran,GPU_premiere_ligne
		;move.l	#(200+premiere_ligne_a_l_ecran)*2,GPU_derniere_ligne			; 508/2=254 ; 254-13=241
		;move.l	#60,_50ou60hertz	
			
				
				move.l  #0,BORD1                ; Black border
                move.w  #0,BG                   ; Init line buffer to black
                movem.l (sp)+,d0-d6
                rts


;-----------------------------------------------------------------------------------
; preparation de l'Objects list
;   Condition codes (CC):
;
;       Values     Comparison/Branch
;     --------------------------------------------------
;        000       Branch on equal            (VCnt==VC)
;        001       Branch on less than        (VCnt>VC)
;        010       Branch on greater than     (VCnt<VC)
;        011       Branch if OP flag is set
; input A6=adresse object list 
preparation_OL:
	move.l	a6,a1

;
; ============== insertion de Branch if YPOS < 0 a X+16

	move.l		#$00000003,d0					; branch
	or.l		#%0100000000000000,d0			; <
	move.l		GPU_premiere_ligne,d3
	;add.l		d3,d3							; *2 : half line
	lsl.l		#3,d3
	or.l		d3,d0							; Ymax	

	move.l		a1,d1
	add.l		#16,d1
	lsr.l		#3,d1							
	move.l		d1,d2
	lsl.l		#8,d1							; <<24 : 8 bits
	lsl.l		#8,d1
	lsl.l		#8,d1
	or.l		d1,d0
	lsr.l		#8,d2
	move.l		d2,(a1)+
	move.l		d0,(a1)+

; ============== insertion de Branch if YPOS < Ymax+1 à X+16

	move.l		#$00000003,d0					; branch
	or.l		#%0100000000000000,d0			; <
	;move.l		#derniere_ligne,d3
	;add.l		d3,d3							; *2 : half line
	;moveq		#0,d3
	move.l		GPU_derniere_ligne,d3
	;add.l		d3,d3							; *2 : half line
	add.l		#1,d3							; integre ligne gpu inteerupt
	lsl.l		#3,d3
	or.l		d3,d0							; Ymax	
	move.l		a1,d1
	add.l		#16,d1
	lsr.l		#3,d1							
	move.l		d1,d2
	lsl.l		#8,d1							; <<24 : 8 bits
	lsl.l		#8,d1
	lsl.l		#8,d1
	or.l		d1,d0
	lsr.l		#8,d2
	move.l		d2,(a1)+
	move.l		d0,(a1)+

; ============== insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+

; ============== insertion de Branch if YPOS < Ymax à X+16

	move.l		#$00000003,d0					; branch
	or.l		#%0100000000000000,d0			; <
	;move.l		#derniere_ligne,d3
	;add.l		d3,d3							; *2 : half line
	;moveq		#0,d3
	move.l		GPU_derniere_ligne,d3
	;add.l		d3,d3							; *2 : half line
	lsl.l		#3,d3
	or.l		d3,d0							; Ymax	
	move.l		a1,d1
	add.l		#16+8,d1						; branch+gpu interrupt+stop
	lsr.l		#3,d1							
	move.l		d1,d2
	lsl.l		#8,d1							; <<24 : 8 bits
	lsl.l		#8,d1
	lsl.l		#8,d1
	or.l		d1,d0
	lsr.l		#8,d2
	move.l		d2,(a1)+
	move.l		d0,(a1)+

; insertion GPU object
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#$3FFA,d0				; $3FFA
	move.l		d0,(a1)+
	
; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+

; A1 = debut bitmap = OL+48



; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+
; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+

; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a1)+
	move.l		#4,d0
	move.l		d0,(a1)+


; insertion de STOP
	moveq		#0,d0
	move.l		d0,(a2)+
	move.l		#4,d0
	move.l		d0,(a2)+

	rts

; ------------------------- creation table rasters ---------------
creation_table_rasters:
	move.l	#$7f,d1                  
	lea		table_parametres_rasters,a0                   
	lea 	motif_raster__data,a1             

creation_table_rasters__boucle2:
	movea.l 	a1,a3                   
	moveq	 	#$a,d0                   
	movea.l 	a0,a2                   

creation_table_rasters__boucle1:	
	move.b 		(a2),d7                 ; D7 = nb lignes du rouleau * 2
	move.b 		1(a2),d6               	; D6 = position du rouleau
	move.b 		2(a2),d4         		; D4 = choix du jeu de couleurs      
	andi.l 		#$ff,d7                  
	andi.l 		#$ff,d6                  
	add.l 		d6,d6                     ; *2
	add.l 		d6,d6                     ; *4
	add.l 		d6,d6                     ; *8
	adda.l 		d6,a3                    
	bsr.s 		creation_table_rasters__1frame
	adda.l 		#$4,a2                   
	movea.l 	a1,a3                   
	dbra 		d0,creation_table_rasters__boucle1       
	
	lea			$40(a0),a0
	lea			(198*2*4)(a1),a1
	dbra 		d1,creation_table_rasters__boucle2     
	rts

creation_table_rasters__1frame:
	movem.l 	d0-d7/a0-a6,-(a7)       
	movea.l 	a3,a2                   
	add.l 		d7,d7 			; *2                    
	add.l 		d7,d7 			; *4
	add.l 		d7,d7 			; *8                    
	adda.l 		d7,a3
	
	lsr.w 		#3,d7           ; /4
	
;	tst.b 		d4                        
;	bne.l 		+$a {$01525a}             
	lea 		raster__rouleau_orange,a0                   
	
	;bra.s 		+$2e {$015288}            
	;cmp.b #$1,d4                    
	;bne.l +$a {$01526a}             
	;lea $186dc,a0                   
	;bra.s +$1e {$015288}            
	;cmp.b #$2,d4                    
	;bne.l +$a {$01527a}             
	;lea $186a4,a0                   
	;bra.s +$e {$015288}             
	;cmp.b #$3,d4                    
	;bne.l +$8 {$015288}             
	;lea $18714,a0                   
creation_table_rasters__1frame__boucle1:	
	move.b		(a0)+,d4				; octet de valeur du pixel sur 256 couleurs
	
	.rept		8
	move.b		d4,(a2)+				; 8 octets
	.endr

	.rept		8
	move.b		d4,-(a3)				; 8 octets
	.endr
	
	;move.w 		(a0),(a2)+               
	;move.w 		(a0)+,-(a3)              
	cmpa.l 		a2,a3                    
	ble.s 		creation_table_rasters__1frame__sortie
	dbf 		d7,creation_table_rasters__1frame__boucle1        

creation_table_rasters__1frame__sortie:
	movem.l 	(a7)+,d0-d7/a0-a6       
	rts                             


;-----------------------------------------------------------------


	.gpu
GPU_debut:
	.org	G_RAM
GPU_base_memoire:

GPU_init:

	movei	#GPU_ISP+(GPU_STACK_SIZE*4),r31			; init isp				6
	moveq	#0,r1										;						2
	moveta	r31,r31									; ISP (bank 0)		2
	nop													;						2
	movei	#GPU_USP+(GPU_STACK_SIZE*4),r31			; init usp				6

	moveq	#$0,R0										; 2
	moveta	R0,R26							; compteur	  2
	movei	#interrupt_OP,R1							; 6
	moveta	R1,R27										; 2


	movei	#OBF,R0									; 6
	moveta	R0,R22										; 2

	movei	#G_FLAGS,R1											; GPU flags
	moveta	R1,R28


	jr		GPU_init_suite							;						2
	nop
; Object Processor interrupt
	jump	(R27)
	nop

;	.rept	6
;		nop
;	.endr
; Blitter
;	.rept	8
;		nop
;	.endr

GPU_init_suite:
	movei		#BG,R10
	moveta		R10,R10
	moveq		#0,R11
	moveta		R11,R11				; R11 = couleur en cours





	movei	#G_FLAGS,r30

	movei	#G_OPENA|REGPAGE,r29			; object list interrupt
	nop
	nop
	store	r29,(r30)
	nop
	nop

; swap les pointeurs d'OL
		movei	#GPU_pointeur_object_list_a_modifier,R0
		movei	#GPU_pointeur_object_list_a_afficher,R1
		load	(R0),R2
		load	(R1),R3
		store	R2,(R1)
		movei	#OLP,R4
		moveta	R3,R3
		rorq	#16,R2
		store	R3,(R0)

		store	R2,(R4)



;----------------------------------------------
;----------------------------------------------
;----------------------------------------------


GPU_main_loop:

; -------------------------------
; avance la position en X
		movei	#position_logo_en_X,R3
		movei	#increment_logo_en_X,R2
		movei	#logo_X_maximal,R1
		load	(R3),R10					; R10 = pos en X
		load	(R2),R11					; R11 = increment



		add		R11,R10
		cmp		R1,R10
		jr		mi,GPU_pas_de_bouclage_position_en_X_du_logo
		nop
		neg		R11
		or		R11,R11
		store	R11,(R2)
GPU_pas_de_bouclage_position_en_X_du_logo:
		cmpq	#0,R10
		jr		hi,GPU_pas_de_bouclage_position_en_X_du_logo__pas_neg
		nop
		jr		ne,GPU_pas_de_bouclage_position_en_X_du_logo__pas_neg
		nop
		neg		R11
		or		R11,R11
		store	R11,(R2)
GPU_pas_de_bouclage_position_en_X_du_logo__pas_neg:
		or		R10,R10
		store	R10,(R3)



; -------------------------------
; avance la position en Y
		movei	#position_logo_en_Y,R0
		movei	#increment_logo_en_Y,R2
		movei	#logo_Y_maximal,R1
		load	(R0),R10					; R10 = pos en Y
		load	(R2),R11					; R11 = increment
		add		R11,R10
		cmp		R1,R10
		jr		mi,GPU_pas_de_bouclage_position_en_Y_du_logo
		nop
		neg		R11
		store	R11,(R2)
		jr		GPU_pas_de_bouclage_position_en_Y_du_logo__pas_neg
GPU_pas_de_bouclage_position_en_Y_du_logo:
		cmpq	#0,R10
		jr		hi,GPU_pas_de_bouclage_position_en_Y_du_logo__pas_neg
		nop
		;jr		ne,GPU_pas_de_bouclage_position_en_Y_du_logo__pas_neg
		;nop
		neg		R11
		store	R11,(R2)
GPU_pas_de_bouclage_position_en_Y_du_logo__pas_neg:
		store	R10,(R0)


; calculer position_Y_debut_lecture_du_logo et hauteur_de_logo_a_afficher
; avec R10 = position_logo_en_Y qui varie entre 0 et 240
;						en Y , zone de 103 lignes de vide, 314 lignes de logo. la pos Y varie de 0 a 240 => 
;								pos Y debut lecture logo = pos Y - 103 // si négatif on lit le logo a partir de 0 sur hauteur = 198- (-( pos Y -103 ))   + position relle du logo en Y = 
;																			si positif, on lit le logo a partir de (pos Y -103) sur 314-

		movei	#position_Y_debut_lecture_du_logo,R20
		;movei	#hauteur_de_logo_a_afficher,R21
		movei	#position_reelle_du_logo_en_Y,R22
		movei	#logo_replicants__nb_lignes_vide_au_dessus,R12			; 102
; R10 = position_logo_en_Y		
		
		
		cmp		R12,R10		
		jr		mi,GPU__gestion_deplacement_logo_en_Y__il_ya_toujours_zone_de_vide
		nop
; position en Y >= 102
		sub		R12,R10			; nb lignes du logo qui dépasse en haut
		moveq	#0,R0
		store	R10,(R20)
		store	R0,(R22)
		


		jr		GPU_calculs_affichage_logo_en_Y__sortie
GPU__gestion_deplacement_logo_en_Y__il_ya_toujours_zone_de_vide:
; position en Y < 102
		moveq	#0,R0			; on commence au debut du logo
		sub		R10,R12
		store	R0,(R20)
		store	R12,(R22)

GPU_calculs_affichage_logo_en_Y__sortie:


; calculés : LINK / 
; toujours identique : DEPTH / PITCH / DWIDTH / IWIDTH / TRANS

 ;63       56        48        40       32        24       16       8        0
 ; +--------^---------^-----+------------^--------+--------^--+-----^----+---+
 ; |        data-address    |     Link-address    |   Height  |   YPos   |000|
 ; +------------------------+---------------------+-----------+----------+---+
 ;     63 .............43        42.........24      23....14    13....3   2.0
 ;          21 bits                 19 bits        10 bits     11 bits  3 bits
 ;                                   (11.8)

; 63       56        48        40       32       24       16        8        0
;  +--------^-+------+^----+----^--+-----^---+----^----+---+---+----^--------+
;  | unused   |1stpix| flag|  idx  | iwidth  | dwidth  | p | d |   x-pos     |
;  +----------+------+-----+-------+---------+---------+---+---+-------------+
;    63...55   54..49 48.45  44.38   37..28    27..18 17.15 14.12  11.....0
;      9bit      6bit  4bit   7bit    10bit    10bit   3bit 3bit    12bit
;                                    (6.4)

; R1 = 8140C000 = depth+pitch+dwidth+iwidth
; R2 = 8140C000 = depth+pitch+dwidth+iwidth
; R3 = TRANS
; R4 = 		movei	#$8000,R3			; TRANS=1

; R9 = premiere ligne haut OL

; R10 = Heigth + Ypos +000    / par ligne
; R11 = X
; R12 = Y
; R13 = data sprite
; R14 = height
; R16 = link tmp
; R17 = LINK
; R18 = pointeur sur bloc a utiliser
; R19 = Y tmp

; R20 = 
; R21 = 
; R23 = GPU_pointeurs_blocs_OL
; R24 = pointeur sur l'OL à modifier = GPU_pointeur_object_list_a_modifier + OL_taille_bloc_de_bras_tiles
; R28 = 

; phrase = 64 bits = 8 octets

; R21 = pointeur raster
		movei	#index_raster,R0
		movei	#$7F,R1
		movei	#(198*8),R2
		movei	#motif_raster__data,R13
		load	(R0),R10						; index actuel
			movei	#GPU_pointeur_object_list_a_modifier,R20
		addq	#1,R10
			movei	#GPU_premiere_ligne,R25
		and		R1,R10							; pour bouclage de l'index
			load	(R20),R18			; R18 = pointeur sur OL
		store	R10,(R0)
			load	(R25),R9
		mult	R2,R10
		movei	#(3<<12)+(0<<15)+(1<<18)+(%0111<<28),R2		; 4 bits de iwidth << 28		; depth=3  / Pitch=0 / DWIDTH=1 / IWIDTH=0  : 4<<12 + 0<<15 + 0<<18 + 1<<28 : $4000 + $10000000
		add		R10,R13
		
		

		;movei	#$8140C000,R2		; depth=4  / Pitch=1 / DWIDTH=80 / IWIDTH=8  : 4<<12 + 1<<15 + 80<<18 + 8<<28
		;movei	#$8280C000,R2		; depth=4  / Pitch=1 / DWIDTH=160 / IWIDTH=8  : 4<<12 + 1<<15 + 160<<18 + 8<<28 : $4000 + $8000 + $2800000 + $80000000

		;movei	#$10004000,R2		; depth=4  / Pitch=0 / DWIDTH=0 / IWIDTH=1  : 4<<12 + 0<<15 + 0<<18 + 1<<28 : $4000 + $10000000

		; la suite de IWIDTH va sur R4
		
		addq	#32,R18				; OL + 32
		shrq	#1,R9
		movei	#(1<<15)+(%0010),R4		; TRANS = 1 ( <<15 ) + 6 bits de iwidth			(5 = 320 pixels)
		addq	#16,R18				; OL + 16 = +48

		.if		rasters=1


		movei	#0,R12				; R12=Y
		movei	#largeur_bande_gauche-14,R11				; R11=X
		;movei	#motif_raster__data,R13			; R13=data
		
		add		R9,R12				; Y + ligne du haut/1ere ligne
		sharq	#3,R13				; DATA sur phrase
		movei	#198,R14				; R14=height
		shlq	#3+1,R12			; Ypos * 2 << 3
		move	R18,R17				; R17=LINK
		shlq	#14,R14				; height << 14
		addq	#16,R17				; R17=LINK
		or		R14,R12				; R12 = Height  |   YPos   |000|
		sharq	#3,R17				; LINK sur phrase
		move	R17,R16				; R16=LINK pour 2eme mot
		shlq	#11,R13				; decalage DATA
		sharq	#8,R17				; R17=LINK pour 1er mot

		or		R17,R13				; 1er mot : LINK + data
		store	R13,(R18)				; store 1er mot
		shlq	#24,R16				; R16=LINK pour 2eme mot
		addq	#4,R18
		or		R16,R12				; Link-address    |   Height  |   YPos   |000|
		store	R12,(R18)				; store 2eme mot
		
		move	R2,R1		
		addq	#4,R18
		move	R4,R3			; TRANS=1
		or		R11,R1				; + X
		store	R3,(R18)
		addq	#4,R18
		store	R1,(R18)
		addq	#4,R18
		.endif

; ------------------ logo replicants
; inserer sprite logo
		movei	#position_logo_en_X,R0
		movei	#logo_replicants,R13
		load	(R0),R1
		or		R1,R1
		movei	#(3<<12)+(1<<15)+((2240/8)<<18)+(%0111<<28),R2		; 4 bits de iwidth << 28		; depth=3  / Pitch=1 / DWIDTH=1 / IWIDTH=0  : 4<<12 + 0<<15 + 0<<18 + 1<<28 : $4000 + $10000000
		add		R1,R13					; increment en X
		movei	#(1<<15)+(%0010),R4								; TRANS = 1 ( <<15 ) + 6 bits de iwidth
		;movei	#motif_raster__data,R13			; R13=data

		;movei	#hauteur_de_logo_a_afficher,R11
		movei	#position_Y_debut_lecture_du_logo,R6
		;load	(R11),R14				; hauteur de logo a afficher
		;movei	#200,R14				; R14=height

		load	(R6),R10
		movei	#largeur_logo_replicants_en_octets,R5
		move	R10,R1
		;sub		R10,R14
		;movei	#200,R11
		;cmp		R11,R14
		;jr		mi,GPU_pas_plus_de_N_lignes
		;nop
		;move	R11,R14

		
		mult	R5,R10
		or		R10,R10
		movei	#position_reelle_du_logo_en_Y,R17
		add		R10,R13
		load	(R17),R12			; R12 = Y

		movei	#200,R14				; R14=height
		movei	#314,R0
		sub		R12,R14

; R1 = ligne debut lecture du logo		
		add		R14,R1
		cmp		R0,R1
		jr		mi,GPU_pas_plus_de_N_lignes
		nop
		sub		R0,R1					; R1 = depassement
		sub		R1,R14
		
GPU_pas_plus_de_N_lignes:	
		;cmpq	#0,R12
		;jr		ne,EDZ1
		;nop
		;nop
;EDZ1:

; edz,edz
		;movei	#3,R12				; R12=Y				0 1 2 idem
; edz,edz



		movei	#largeur_bande_gauche-14,R11				; R11=X

		
		add		R9,R12				; Y + ligne du haut/1ere ligne
		sharq	#3,R13				; DATA sur phrase
		shlq	#3+1,R12			; Ypos * 2 << 3
		move	R18,R17				; R17=LINK
		shlq	#14,R14				; height << 14
		addq	#16,R17				; R17=LINK
		or		R14,R12				; R12 = Height  |   YPos   |000|
		sharq	#3,R17				; LINK sur phrase
		move	R17,R16				; R16=LINK pour 2eme mot
		shlq	#11,R13				; decalage DATA
		sharq	#8,R17				; R17=LINK pour 1er mot

		or		R17,R13				; 1er mot : LINK + data
		store	R13,(R18)				; store 1er mot
		shlq	#24,R16				; R16=LINK pour 2eme mot
		addq	#4,R18
		or		R16,R12				; Link-address    |   Height  |   YPos   |000|
		store	R12,(R18)				; store 2eme mot
		
		move	R2,R1		
		addq	#4,R18
		move	R4,R3			; TRANS=1
		or		R11,R1				; + X
		store	R3,(R18)
		addq	#4,R18
		store	R1,(R18)
		addq	#4,R18



; inserer equalizeurs à gauche = 3 sprites

; rouge
		movei	#GPU_volume_A,R0
		movei	#12,R2
		load	(R0),R1				; entre 0 et 15 : => 
		movei	#200,R3
		mult	R2,R1				; entre 0 et 180
		sub		R1,R3
	; R1 = hauteur
	; R3 = position Y
		
	
	
		movei		#equalizeur_rouge,R13
		movei		#24,R11					; R11 = X
		move		R3,R12					; R12 = Y
		move		R1,R14				; R14=height

		movei	#(1<<15)+(0),R4								; TRANS = 1 ( <<15 ) + 6 bits de iwidth
		movei	#(4<<12)+(1<<15)+((8/8)<<18)+(01<<28),R2		; 4 bits de iwidth << 28		; depth=4 RGB 16 bits  / Pitch=1 / DWIDTH=1 / IWIDTH=0  : 4<<12 + 0<<15 + 0<<18 + 1<<28 : $4000 + $10000000


		add		R9,R12				; Y + ligne du haut/1ere ligne
		sharq	#3,R13				; DATA sur phrase
		shlq	#3+1,R12			; Ypos * 2 << 3
		move	R18,R17				; R17=LINK
		shlq	#14,R14				; height << 14
		addq	#16,R17				; R17=LINK
		or		R14,R12				; R12 = Height  |   YPos   |000|
		sharq	#3,R17				; LINK sur phrase
		move	R17,R16				; R16=LINK pour 2eme mot
		shlq	#11,R13				; decalage DATA
		sharq	#8,R17				; R17=LINK pour 1er mot

		or		R17,R13				; 1er mot : LINK + data
		store	R13,(R18)				; store 1er mot
		shlq	#24,R16				; R16=LINK pour 2eme mot
		addq	#4,R18
		or		R16,R12				; Link-address    |   Height  |   YPos   |000|
		store	R12,(R18)				; store 2eme mot
		
		move	R2,R1		
		addq	#4,R18
		move	R4,R3			; TRANS=1
		or		R11,R1				; + X
		store	R3,(R18)
		addq	#4,R18
		store	R1,(R18)
		addq	#4,R18
		
; bleu
		movei	#GPU_volume_B,R0
		movei	#12,R2
		load	(R0),R1				; entre 0 et 15 : => 
		movei	#200,R3
		mult	R2,R1				; entre 0 et 180
		sub		R1,R3
	; R1 = hauteur
	; R3 = position Y


		movei		#equalizeur_bleu,R13
		movei		#24+4,R11					; R11 = X
		move		R3,R12					; R12 = Y
		move		R1,R14				; R14=height

		movei	#(1<<15)+(0),R4								; TRANS = 1 ( <<15 ) + 6 bits de iwidth
		movei	#(4<<12)+(1<<15)+((8/8)<<18)+(01<<28),R2		; 4 bits de iwidth << 28		; depth=4 RGB 16 bits  / Pitch=1 / DWIDTH=1 / IWIDTH=0  : 4<<12 + 0<<15 + 0<<18 + 1<<28 : $4000 + $10000000


		add		R9,R12				; Y + ligne du haut/1ere ligne
		sharq	#3,R13				; DATA sur phrase
		shlq	#3+1,R12			; Ypos * 2 << 3
		move	R18,R17				; R17=LINK
		shlq	#14,R14				; height << 14
		addq	#16,R17				; R17=LINK
		or		R14,R12				; R12 = Height  |   YPos   |000|
		sharq	#3,R17				; LINK sur phrase
		move	R17,R16				; R16=LINK pour 2eme mot
		shlq	#11,R13				; decalage DATA
		sharq	#8,R17				; R17=LINK pour 1er mot

		or		R17,R13				; 1er mot : LINK + data
		store	R13,(R18)				; store 1er mot
		shlq	#24,R16				; R16=LINK pour 2eme mot
		addq	#4,R18
		or		R16,R12				; Link-address    |   Height  |   YPos   |000|
		store	R12,(R18)				; store 2eme mot
		
		move	R2,R1		
		addq	#4,R18
		move	R4,R3			; TRANS=1
		or		R11,R1				; + X
		store	R3,(R18)
		addq	#4,R18
		store	R1,(R18)
		addq	#4,R18
		
; vert
		movei	#GPU_volume_C,R0
		movei	#12,R2
		load	(R0),R1				; entre 0 et 15 : => 
		movei	#200,R3
		mult	R2,R1				; entre 0 et 180
		sub		R1,R3
	; R1 = hauteur
	; R3 = position Y
		
	
	
		movei		#equalizeur_vert,R13
		movei		#24+4+4,R11					; R11 = X
		move		R3,R12					; R12 = Y
		move		R1,R14				; R14=height

		movei	#(1<<15)+(0),R4								; TRANS = 1 ( <<15 ) + 6 bits de iwidth
		movei	#(4<<12)+(1<<15)+((8/8)<<18)+(01<<28),R2		; 4 bits de iwidth << 28		; depth=4 RGB 16 bits  / Pitch=1 / DWIDTH=1 / IWIDTH=0  : 4<<12 + 0<<15 + 0<<18 + 1<<28 : $4000 + $10000000


		add		R9,R12				; Y + ligne du haut/1ere ligne
		sharq	#3,R13				; DATA sur phrase
		shlq	#3+1,R12			; Ypos * 2 << 3
		move	R18,R17				; R17=LINK
		shlq	#14,R14				; height << 14
		addq	#16,R17				; R17=LINK
		or		R14,R12				; R12 = Height  |   YPos   |000|
		sharq	#3,R17				; LINK sur phrase
		move	R17,R16				; R16=LINK pour 2eme mot
		shlq	#11,R13				; decalage DATA
		sharq	#8,R17				; R17=LINK pour 1er mot

		or		R17,R13				; 1er mot : LINK + data
		store	R13,(R18)				; store 1er mot
		shlq	#24,R16				; R16=LINK pour 2eme mot
		addq	#4,R18
		or		R16,R12				; Link-address    |   Height  |   YPos   |000|
		store	R12,(R18)				; store 2eme mot
		
		move	R2,R1		
		addq	#4,R18
		move	R4,R3			; TRANS=1
		or		R11,R1				; + X
		store	R3,(R18)
		addq	#4,R18
		store	R1,(R18)
		addq	#4,R18

; droite
; vert a droite
		movei	#GPU_volume_C,R0
		movei	#12,R2
		load	(R0),R1				; entre 0 et 15 : => 
		movei	#200,R3
		mult	R2,R1				; entre 0 et 180
		sub		R1,R3
	; R1 = hauteur
	; R3 = position Y
		
	
	
		movei		#equalizeur_vert,R13
		movei		#largeur_bande_gauche-14+320-12+4,R11					; R11 = X
		move		R3,R12					; R12 = Y
		move		R1,R14				; R14=height

		movei	#(1<<15)+(0),R4								; TRANS = 1 ( <<15 ) + 6 bits de iwidth
		movei	#(4<<12)+(1<<15)+((8/8)<<18)+(01<<28),R2		; 4 bits de iwidth << 28		; depth=4 RGB 16 bits  / Pitch=1 / DWIDTH=1 / IWIDTH=0  : 4<<12 + 0<<15 + 0<<18 + 1<<28 : $4000 + $10000000


		add		R9,R12				; Y + ligne du haut/1ere ligne
		sharq	#3,R13				; DATA sur phrase
		shlq	#3+1,R12			; Ypos * 2 << 3
		move	R18,R17				; R17=LINK
		shlq	#14,R14				; height << 14
		addq	#16,R17				; R17=LINK
		or		R14,R12				; R12 = Height  |   YPos   |000|
		sharq	#3,R17				; LINK sur phrase
		move	R17,R16				; R16=LINK pour 2eme mot
		shlq	#11,R13				; decalage DATA
		sharq	#8,R17				; R17=LINK pour 1er mot

		or		R17,R13				; 1er mot : LINK + data
		store	R13,(R18)				; store 1er mot
		shlq	#24,R16				; R16=LINK pour 2eme mot
		addq	#4,R18
		or		R16,R12				; Link-address    |   Height  |   YPos   |000|
		store	R12,(R18)				; store 2eme mot
		
		move	R2,R1		
		addq	#4,R18
		move	R4,R3			; TRANS=1
		or		R11,R1				; + X
		store	R3,(R18)
		addq	#4,R18
		store	R1,(R18)
		addq	#4,R18

; bleu a droite
		movei	#GPU_volume_B,R0
		movei	#12,R2
		load	(R0),R1				; entre 0 et 15 : => 
		movei	#200,R3
		mult	R2,R1				; entre 0 et 180
		sub		R1,R3
	; R1 = hauteur
	; R3 = position Y


		movei		#equalizeur_bleu,R13
		movei		#largeur_bande_gauche-14+320-12+4+4,R11					; R11 = X
		move		R3,R12					; R12 = Y
		move		R1,R14				; R14=height

		movei	#(1<<15)+(0),R4								; TRANS = 1 ( <<15 ) + 6 bits de iwidth
		movei	#(4<<12)+(1<<15)+((8/8)<<18)+(01<<28),R2		; 4 bits de iwidth << 28		; depth=4 RGB 16 bits  / Pitch=1 / DWIDTH=1 / IWIDTH=0  : 4<<12 + 0<<15 + 0<<18 + 1<<28 : $4000 + $10000000


		add		R9,R12				; Y + ligne du haut/1ere ligne
		sharq	#3,R13				; DATA sur phrase
		shlq	#3+1,R12			; Ypos * 2 << 3
		move	R18,R17				; R17=LINK
		shlq	#14,R14				; height << 14
		addq	#16,R17				; R17=LINK
		or		R14,R12				; R12 = Height  |   YPos   |000|
		sharq	#3,R17				; LINK sur phrase
		move	R17,R16				; R16=LINK pour 2eme mot
		shlq	#11,R13				; decalage DATA
		sharq	#8,R17				; R17=LINK pour 1er mot

		or		R17,R13				; 1er mot : LINK + data
		store	R13,(R18)				; store 1er mot
		shlq	#24,R16				; R16=LINK pour 2eme mot
		addq	#4,R18
		or		R16,R12				; Link-address    |   Height  |   YPos   |000|
		store	R12,(R18)				; store 2eme mot
		
		move	R2,R1		
		addq	#4,R18
		move	R4,R3			; TRANS=1
		or		R11,R1				; + X
		store	R3,(R18)
		addq	#4,R18
		store	R1,(R18)
		addq	#4,R18

; rouge a droite
; rouge
		movei	#GPU_volume_A,R0
		movei	#12,R2
		load	(R0),R1				; entre 0 et 15 : => 
		movei	#200,R3
		mult	R2,R1				; entre 0 et 180
		sub		R1,R3
	; R1 = hauteur
	; R3 = position Y
		
	
	
		movei		#equalizeur_rouge,R13
		movei		#largeur_bande_gauche-14+320-12+8+4,R11					; R11 = X
		move		R3,R12					; R12 = Y
		move		R1,R14				; R14=height

		movei	#(1<<15)+(0),R4								; TRANS = 1 ( <<15 ) + 6 bits de iwidth
		movei	#(4<<12)+(1<<15)+((8/8)<<18)+(01<<28),R2		; 4 bits de iwidth << 28		; depth=4 RGB 16 bits  / Pitch=1 / DWIDTH=1 / IWIDTH=0  : 4<<12 + 0<<15 + 0<<18 + 1<<28 : $4000 + $10000000


		add		R9,R12				; Y + ligne du haut/1ere ligne
		sharq	#3,R13				; DATA sur phrase
		shlq	#3+1,R12			; Ypos * 2 << 3
		move	R18,R17				; R17=LINK
		shlq	#14,R14				; height << 14
		addq	#16,R17				; R17=LINK
		or		R14,R12				; R12 = Height  |   YPos   |000|
		sharq	#3,R17				; LINK sur phrase
		move	R17,R16				; R16=LINK pour 2eme mot
		shlq	#11,R13				; decalage DATA
		sharq	#8,R17				; R17=LINK pour 1er mot

		or		R17,R13				; 1er mot : LINK + data
		store	R13,(R18)				; store 1er mot
		shlq	#24,R16				; R16=LINK pour 2eme mot
		addq	#4,R18
		or		R16,R12				; Link-address    |   Height  |   YPos   |000|
		store	R12,(R18)				; store 2eme mot
		
		move	R2,R1		
		addq	#4,R18
		move	R4,R3			; TRANS=1
		or		R11,R1				; + X
		store	R3,(R18)
		addq	#4,R18
		store	R1,(R18)
		addq	#4,R18


; inserer un stop

		moveq	#0,R25			; STOP : 0
		moveq	#4,R16			; STOP : 4
		store	R25,(R18)
		addq	#4,R18
		store	R16,(R18)




;----------------------------------------------
; incremente compteur de VBL au GPU
		movei	#vbl_counter_GPU,R0
		load	(R0),R1
		addq	#1,R1
		store	R1,(R0)

		;movei	#BG,R26
		;moveq	#0,R25				; bleu
		;storew	R25,(R26)







		
		
		.if			1=0
		move	R10,R11
		sub		R12,R11			; pos Y - 103
		cmpq	#0,R11
		jr		pl,GPU_pas_de_zone_de_vide_en_Y_a_afficher
		nop
		moveq	#0,R0
		neg		R11
		store	R0,(R20)
		;movei	#198,R13
		store	R11,(R22)
		;sub		R11,R13
		;store	R13,(R21)
		jr		GPU_calculs_affichage_logo_en_Y__sortie
		nop

GPU_pas_de_zone_de_vide_en_Y_a_afficher:
		moveq	#0,R0
		store	R11,(R20)
		store	R0,(R22)
GPU_calculs_affichage_logo_en_Y__sortie:

		.endif
		






; synchro avec l'interrupt object list
		movefa	R26,R26
		
GPU_boucle_wait_vsync:
		movefa	R26,R25
		cmp		R25,R26
		jr		eq,GPU_boucle_wait_vsync
		nop
		




; swap les pointeurs d'OL
		movei	#GPU_pointeur_object_list_a_modifier,R0
		movei	#GPU_pointeur_object_list_a_afficher,R1
		load	(R0),R2
		load	(R1),R3				; R3 = pointeur sur l'object list a modifier prochaine frame
		store	R2,(R1)
		movei	#OLP,R4
		;moveta	R3,R3
		rorq	#16,R2
		store	R3,(R0)

		store	R2,(R4)


	movei	#GPU_main_loop,R27
	jump		(R27)
	nop

;----------------------------------------------
;----------------------------------------------
;----------------------------------------------



;--------------------------------------------------------
;
; interruption object processor
;	- libere l'OP
;	- incremente R26
; utilises : R0/R22/R26/R28/R29/R30/R31
;
;--------------------------------------------------------
interrupt_OP:
		storew		R0,(r22)					; R22 = OBF
		load     (R28),r29
		addq     #1,r26							; incremente R26
		load     (R31),r30
		bclr     #3,r29
		addq     #2,r30
		addq     #4,r31
		bset     #12,r29
		jump     (r30)
		store    r29,(r28)

	.dphrase
vbl_counter_GPU:								dc.l		5424
GPU_pointeur_object_list_a_modifier:			dc.l			ob_list_1
GPU_pointeur_object_list_a_afficher:			dc.l			ob_list_2
GPU_premiere_ligne:				dc.l		0				; lus 2 fois
GPU_derniere_ligne:				dc.l		0

index_raster:		dc.l		0

; gestion du deplacement en X du logo
position_logo_en_X:		dc.l		0
increment_logo_en_X:	dc.l		increment_en_X_logo			; 13

; gestion du deplacement en Y du logo
position_Y_debut_lecture_du_logo:		dc.l		0
;hauteur_de_logo_a_afficher:				dc.l		198
position_reelle_du_logo_en_Y:			dc.l		0

position_logo_en_Y:		dc.l		0
increment_logo_en_Y:	dc.l		increment_en_Y_logo

GPU_volume_A:			dc.l		13			; de 0 a 15
GPU_volume_B:			dc.l		15			; de 0 a 15
GPU_volume_C:			dc.l		11			; de 0 a 15

		
;---------------------
; FIN DE LA RAM GPU
GPU_fin:
;---------------------	

GPU_DRIVER_SIZE			.equ			GPU_fin-GPU_base_memoire
	.print	"---------------------------------------------------------------"
	.print	"--- GPU code size : ", /u GPU_DRIVER_SIZE, " bytes / 4096 ---"
	.if GPU_DRIVER_SIZE > 4088
		.print		""
		.print		""
		.print		""
		.print	"---------------------------------------------------------------"
		.print	"          GPU code too large !!!!!!!!!!!!!!!!!! "
		.print	"---------------------------------------------------------------"
		.print		""
		.print		""
		.print		""
		
	.endif



        .68000
		.dphrase
		
		.if			1=0
ob_liste_originale:           				 ; This is the label you will use to address this in 68K code
        .objproc 							   ; Engage the OP assembler
		.dphrase

        .org    ob_list_courante			 ; Tell the OP assembler where the list will execute
;
        branch      VC < 0, .stahp    			 ; Branch to the STOP object if VC < 0
        branch      VC > 200, .stahp   			 ; Branch to the STOP object if VC > 241
			; bitmap data addr, xloc, yloc, dwidth, iwidth, iheight, bpp, pallete idx, flags, firstpix, pitch
		bitmap		trame_ligne,50,150,nb_octets_par_ligne/8,nb_octets_par_ligne/8,1, 4,0, TRANS,0,0


        bitmap      ecran1, 16, 26, nb_octets_par_ligne/8, nb_octets_par_ligne/8, 246-26,4
		;bitmap		trame_ligne,50,150,nb_octets_par_ligne/8,nb_octets_par_ligne/8,1, 4, 0, TRANS,0,1
		;bitmap		trame_ligne+5120+512,50,150,nb_octets_par_ligne/8,nb_octets_par_ligne/8,1, 4,0, TRANS,0,0

		bitmap		trame_ligne,50,150,nb_octets_par_ligne/8,nb_octets_par_ligne/8,1, 4,0, TRANS,0,0

		bitmap		trame_ligne,52,150,nb_octets_par_ligne/8,nb_octets_par_ligne/8,1, 4,0, TRANS,0,0
		bitmap		trame_ligne,54,150,nb_octets_par_ligne/8,nb_octets_par_ligne/8,1, 4,0, TRANS,0,0


		;gpuobj		1,10
        jump        .haha
.stahp:
        stop
.haha:
        jump        .stahp
		
		.68000
		.dphrase
fin_ob_liste_originale:
		.endif
			
		.dphrase
;trame_ligne:	
;		.rept		4
;		dc.w		$547
;		.endr
;		.rept		640
;		dc.w		$E540
;		.endr

	.dphrase
raster__rouleau_orange:
;				CRY
;	dc.w		$F020			; 1
;	dc.w		$F040			; 2
;	dc.w		$F060			; 3
;	dc.w		$F080			; 4
;	dc.w		$F0A0			; 5
;	dc.w		$F2C0			; 6
;	dc.w		$F2E0			; 7
;	dc.w		$F4E0			; 8
;	dc.w		$E4E0			; 9
;	dc.w		$E6E0			; 10
;	dc.w		$D5E0			; 11
;	dc.w		$D7E0			; 12
;	dc.w		$C6E0			; 13
;	dc.w		$C8E0			; 14
;	dc.w		$B7E0			; 15
;	dc.w		$A8E0			; 16
;	dc.w		$A8E0			; 17
;	dc.w		$87E0			; 18
;	dc.w		$78E0			; 19
	
;				RGB
;  16-bit RGB.  
;    bits [15-11] are red 
;	 bits [10-06] are blue 
;    Bits [05-00] are green 
;        R5B5G6

	dc.b		1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19

	
	
	
	.phrase
CLUT_RGB:
;1
	dc.w		(%00111<<11)+(%00000<<1)+(00<<6)			;0100
	dc.w		(%01011<<11)+(%00000<<1)+(00<<6)			;0200
	dc.w		(%01111<<11)+(%00000<<1)+(00<<6)			;0300
	dc.w		(%10011<<11)+(%00000<<1)+(00<<6)			;0400
	dc.w		(%10111<<11)+(%00000<<1)+(00<<6)			;0500
	dc.w		(%11011<<11)+(%00111<<1)+(00<<6)			;0610
	dc.w		(%11111<<11)+(%00111<<1)+(00<<6)			;0710
	dc.w		(%11111<<11)+(%01011<<1)+(00<<6)			;0720
	dc.w		(%11111<<11)+(%01011<<1)+(%00111<<6)		;0721
	dc.w		(%11111<<11)+(%01111<<1)+(%00111<<6)		;0731
	dc.w		(%11111<<11)+(%01111<<1)+(%01011<<6)		;0732
	dc.w		(%11111<<11)+(%10011<<1)+(%01011<<6)		;0742
	dc.w		(%11111<<11)+(%10011<<1)+(%01111<<6)		;0743
	dc.w		(%11111<<11)+(%10111<<1)+(%01111<<6)		;0753
	dc.w		(%11111<<11)+(%10111<<1)+(%10011<<6)		;0754
	dc.w		(%11111<<11)+(%11011<<1)+(%10011<<6)		;0764
	dc.w		(%11111<<11)+(%11011<<1)+(%10111<<6)		;0765
	dc.w		(%11111<<11)+(%11011<<1)+(%11011<<6)		;0766
	dc.w		(%11111<<11)+(%11111<<1)+(%11111<<6)		;0777
;20	
;nb couleurs : 40
table_couleur_logo:
        dc.w    $0000
        dc.w    $1084
        dc.w    $1986
        dc.w    $0041
        dc.w    $3ACF
        dc.w    $4310
        dc.w    $5BD7
        dc.w    $6418
        dc.w    $7CDF
        dc.w    $8520
        dc.w    $9DE7
        dc.w    $A628
        dc.w    $BEEF
        dc.w    $C730
        dc.w    $BF2F
        dc.w    $DF37
        dc.w    $E738
        dc.w    $E739
        dc.w    $D6B4
        dc.w    $2A43
        dc.w    $3AC0
        dc.w    $6400
        dc.w    $7CC0
        dc.w    $8500
        dc.w    $9DC0
        dc.w    $A600
        dc.w    $BEC0
        dc.w    $C700
        dc.w    $C701
        dc.w    $C716
        dc.w    $C718
        dc.w    $C717
        dc.w    $C71F
        dc.w    $C720
        dc.w    $C727
        dc.w    $C728
        dc.w    $BF27
        dc.w    $DF2F
        dc.w    $E730
        dc.w    $E731
; 60	
; +109 couleurs font
        dc.w    $0000
        dc.w    $0500
        dc.w    $04C0
        dc.w    $05C0
        dc.w    $0600
        dc.w    $06C0
        dc.w    $0700
        dc.w    $2700
        dc.w    $4700
        dc.w    $66C8
        dc.w    $8610
        dc.w    $A518
        dc.w    $C420
        dc.w    $DB27
        dc.w    $DB28
        dc.w    $E2AC
        dc.w    $E230
        dc.w    $E1F0
        dc.w    $E338
        dc.w    $E3B8
        dc.w    $E438
        dc.w    $E538
        dc.w    $E638
        dc.w    $DEF8
        dc.w    $C738
        dc.w    $A738
        dc.w    $8738
        dc.w    $5EB8
        dc.w    $5E78
        dc.w    $44F8
        dc.w    $11B8
        dc.w    $0078
        dc.w    $0580
        dc.w    $0640
        dc.w    $0680
        dc.w    $1F00
        dc.w    $1700
        dc.w    $3700
        dc.w    $0F00
        dc.w    $5705
        dc.w    $3F00
        dc.w    $768C
        dc.w    $5EC7
        dc.w    $9594
        dc.w    $7E0F
        dc.w    $B49C
        dc.w    $A4D8
        dc.w    $9D17
        dc.w    $D3A4
        dc.w    $C3E0
        dc.w    $C41F
        dc.w    $DAE8
        dc.w    $E1B4
        dc.w    $E137
        dc.w    $E1B8
        dc.w    $E238
        dc.w    $E2B8
        dc.w    $E1F8
        dc.w    $E2F8
        dc.w    $E4B8
        dc.w    $E4F8
        dc.w    $E5B8
        dc.w    $E6B8
        dc.w    $B738
        dc.w    $9738
        dc.w    $76F8
        dc.w    $56C5
        dc.w    $768D
        dc.w    $E1F5
        dc.w    $E3F8
        dc.w    $D738
        dc.w    $44F7
        dc.w    $11F7
        dc.w    $0D0C
        dc.w    $34EE
        dc.w    $45E9
        dc.w    $04C8
        dc.w    $04CC
        dc.w    $0501
        dc.w    $0422
        dc.w    $03A9
        dc.w    $0137
        dc.w    $8611
        dc.w    $D365
        dc.w    $DEB8
        dc.w    $9F38
        dc.w    $2F00
        dc.w    $66C7
        dc.w    $8D93
        dc.w    $E177
        dc.w    $E1B7
        dc.w    $4703
        dc.w    $4F04
        dc.w    $5704
        dc.w    $A519
        dc.w    $BC1F
        dc.w    $AC9B
        dc.w    $C421
        dc.w    $DAAC
        dc.w    $D329
        dc.w    $D328
        dc.w    $E22F
        dc.w    $E175
        dc.w    $4F05
        dc.w    $66C9
        dc.w    $668B
        dc.w    $8612
        dc.w    $9555
        dc.w    $B45D





;  16-bit RGB.  
;    bits [15-11] are red    5 bits
;	 bits [10-06] are blue 	 5 bits
;    Bits [05-00] are green  6 bits
;        R5B5G6	
nb_repetitions_equ		.equ		4
		.dphrase
equalizeur_rouge:
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(02<<11)+(00<<06)+(00)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(04<<11)+(00<<06)+(00)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(08<<11)+(00<<06)+(00)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(12<<11)+(00<<06)+(00)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(18<<11)+(00<<06)+(00)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(24<<11)+(00<<06)+(00)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(27<<11)+(00<<06)+(00)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(31<<11)+(00<<06)+(00)
			.endr
		.endr
		
			.dphrase
equalizeur_bleu:
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(02<<06)+(00)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(04<<06)+(00)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(08<<06)+(00)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(12<<06)+(00)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(18<<06)+(00)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(24<<06)+(00)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(27<<06)+(00)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(31<<06)+(00)
			.endr
		.endr

			.dphrase
equalizeur_vert:
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(00<<06)+(02)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(00<<06)+(04)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(00<<06)+(08)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(00<<06)+(12)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(00<<06)+(18)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(00<<06)+(24)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(00<<06)+(27)
			.endr
		.endr
		.rept	25
			.rept	nb_repetitions_equ
			dc.w	(00<<11)+(00<<06)+(31)
			.endr
		.endr

texte_scrolling:
		dc.b		"abcdefghij      THE FUCKING BEST REPLICANTS ST AMIGOS PRESENTS:- EMLYN HUGUES FOOTBALL - BROKEN BY THE REPLICANTS     ONLY A FEW FUCKINGS TO NOCKTANAL THE CANADIANS DICKHEAD, OVERWANKERS DAY AFTER DAY YEAR AFTER YEAR YOU ARE LAMEST AND LAMEST JUST SOME GREETINGS TO OUR BEST FRIENDS: MCA, AUTOMATION, "
		dc.b		"HOTLINE, TCB, TEX, DEREK MD...  CREDITS FOR THIS SCREEN                    CODING -VICKERS-                    AMIGAFONT RIPPER -VANTAGE- FROM ST CONNEXION                    BIG REPLICANTS LOGO BY -PULSAR- FROM NEXT                    MUSIX -MAD MAX- FROM -T-          END OF SCROLL       "
fin_texte_scrolling:
		even
	
	
	.phrase
table_parametres_rasters:
		.incbin		"replic22__table_parametres_rasters.bin"
		even
	
	.dphrase
 logo_replicants:
 ; 2240 x 314
		.incbin		"replic22_logo.png_JAG"
		even

	.dphrase
font_replicants:
		.incbin		"replic22_font.png_JAG"
		even
		
		.BSS
		ds.b		320*50
		.phrase
DEBUT_BSS:
vbl_counter:			ds.l			1
_50ou60hertz:			ds.l	1
ntsc_flag:				ds.w	1
a_hdb:          		ds.w   1
a_hde:          		ds.w   1
a_vdb:          		ds.w   1
a_vde:          		ds.w   1
width:          		ds.w   1
height:         		ds.w   1
taille_liste_OP:		ds.l	1

            .dphrase
zone_scroller:
						ds.b		320*2*32
;ecran1:				ds.b		640*256				; 8 bitplanes

	.dphrase
motif_raster__data:
	ds.b		2*4*198*128

FIN_RAM:
