; je lis la lettre
; position actuelle dans la lettre, de 0 à 28 / a 32 => 0



; bug scrolling en bas a gauche
; objet en multiple de 16 octets
; data multiple de 8 octets


; coder le scrolling
;  font = 320*256
;  1 caractere = 32*32
; 	Y scrolling = 164
; vitesse = 4 pixels par vbl


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

NUMERO_DE_MUSIQUE			.equ		5

rasters						.equ		1

; constantes scrolling
scrolling__hauteur_de_lettre		.equ		32
scrolling__largeur_de_lettre		.equ		32
scrolling__position_Y_a_l_ecran		.equ		164
scrolling__vitesse					.equ		4


; constantes rasters
increment_en_X_logo			.equ		13			; normal=13 
increment_en_Y_logo			.equ		2			; normal=2

premiere_ligne_a_l_ecran	.equ		49


nb_actuel_de_couleurs		.equ		19+40+50
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


;--------------------
; STEREO
STEREO									.equ			0			; 0=mono / 1=stereo
STEREO_shit_bits						.equ			4
; stereo weights : 0 to 16
YM_DSP_Voie_A_pourcentage_Gauche		.equ			14
YM_DSP_Voie_A_pourcentage_Droite		.equ			2
YM_DSP_Voie_B_pourcentage_Gauche		.equ			10
YM_DSP_Voie_B_pourcentage_Droite		.equ			6
YM_DSP_Voie_C_pourcentage_Gauche		.equ			6
YM_DSP_Voie_C_pourcentage_Droite		.equ			10
YM_DSP_Voie_D_pourcentage_Gauche		.equ			2
YM_DSP_Voie_D_pourcentage_Droite		.equ			14


; algo de la routine qui genere les samples
; 3 canaux : increment onde carrée * 3 , increment noise, volume voie * 3 , increment enveloppe

DSP_DEBUG			.equ			0
DSP_DEBUG_T1		.equ			0
DSP_DEBUG_BUZZER	.equ			0									; 0=Buzzer ON / 1=pas de gestion du buzzer
I2S_during_Timer1	.equ			0									; 0= I2S waits while timer 1 / 1=IMASK cleared while Timer 1
YM_avancer			.equ			1									; 0=on avance pas / 1=on avance
YM_position_debut_dans_musique		.equ		0
YM_Samples_SID_en_RAM_DSP			.equ		1						; 0 = samples SID en RAM 68000 / 1 = samples SID en RAM DSP.
DSP_random_Noise_generator_method	.equ		4						; algo to generate noise random number : 1 & 4 (LFSR) OK uniquement // 2 & 3 : KO
VBLCOUNTER_ON_DSP_TIMER1			.equ		0						; 0=vbl counter in VI interrupt CPU / 1=vbl counter in Timer 1


	
DSP_Audio_frequence					.equ			36000				; real hardware needs lower sample frequencies than emulators !
YM_frequence_YM2149					.equ			2000000				; 2 000 000 = Atari ST , 1 000 000 Hz = Amstrad CPC, 1 773 400 Hz = ZX spectrum 
YM_DSP_frequence_MFP				.equ			2457600
YM_DSP_precision_virgule_digidrums	.equ			11
YM_DSP_precision_virgule_SID		.equ			16
YM_DSP_precision_virgule_envbuzzer	.equ			16


DSP_STACK_SIZE	equ	32	; long words
DSP_USP			equ		(D_ENDRAM-(4*DSP_STACK_SIZE))
DSP_ISP			equ		(DSP_USP-(4*DSP_STACK_SIZE))


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


; ------------------------
; debut DSP
	move.l	#0,D_CTRL

; copie du code DSP dans la RAM DSP

	lea		YM_DSP_debut,A0
	lea		D_RAM,A1
	move.l	#YM_DSP_fin-DSP_base_memoire,d0
	lsr.l	#2,d0
	


	sub.l	#1,D0
boucle_copie_bloc_DSP:
	move.l	(A0)+,(A1)+
	dbf		D0,boucle_copie_bloc_DSP


    bsr   		  InitVideo               	; Setup our video registers.

;check ntsc ou pal:

	moveq		#0,d0
	move.w		JOYBUTS ,d0

	move.l		#26593900,frequence_Video_Clock			; PAL
	move.l		#415530,frequence_Video_Clock_divisee

	
	btst		#4,d0
	beq.s		jesuisenpal
jesuisenntsc:
	move.l		#26590906,frequence_Video_Clock			; NTSC
	move.l		#415483,frequence_Video_Clock_divisee
jesuisenpal:





; creer les object listes
	lea		ob_list_1,a6
	bsr		preparation_OL
	lea		ob_list_2,a6
	bsr		preparation_OL



	move.w		#801,VI			; stop VI


; init CLUT

	lea			CLUT+2,a1
	lea			CLUT_RGB,a0
	move.w		#nb_actuel_de_couleurs-1,d0
copie_clut:
	move.w		(a0)+,(a1)+
	dbf			d0,copie_clut


; init DSP
; $40FC
	; set timers
	move.l		#DSP_Audio_frequence,d0
	move.l		frequence_Video_Clock_divisee,d1
	lsl.l		#8,d1
	divu		d0,d1
	and.l		#$ffff,d1
	add.l		#128,d1			; +0.5 pour arrondir
	lsr.l		#8,d1
	subq.l		#1,d1
	move.l		d1,DSP_parametre_de_frequence_I2S

;calcul inverse
 	addq.l	#1,d1
	add.l	d1,d1		; * 2 
	add.l	d1,d1		; * 2 
	lsl.l	#4,d1		; * 16
	move.l	frequence_Video_Clock,d0
	divu	d1,d0			; 26593900 / ( (16*2*2*(+1))
	and.l		#$ffff,d0
	move.l	d0,DSP_frequence_de_replay_reelle_I2S


; init coso
; ------------- numero de musique
	MOVEQ	#NUMERO_DE_MUSIQUE,D0
	lea		fichier_coso_depacked,a0
	bsr		INITMUSIC

; apres copie on init le YM7
	bsr			YM_init_coso




	
	bsr			creation_table_rasters


; launch GPU

	move.l	#REGPAGE,G_FLAGS
	move.l	#GPU_init,G_PC
	move.l  #RISCGO,G_CTRL	; START GPU

; launch DSP
	move.l	#REGPAGE,D_FLAGS
	move.l	#DSP_routine_init_DSP,D_PC
	move.l	#DSPGO,D_CTRL
	move.l	#0,vbl_counter_replay_DSP
	move.l	#0,vbl_counter


    ;bsr     copy_olist              	; use Blitter to update active list from shadow

	;move.l	#ob_list_courante,d0					; set the object list pointer
	;swap	d0
	;move.l	d0,OLP


	.if		1=0
	move.l  #VBL,LEVEL0     	; Install 68K LEVEL0 handler
	move.w  a_vde,d0                	; Must be ODD
	sub.w   #16,d0
	ori.w   #1,d0
	move.w  d0,VI

	move.w  #%01,INT1                 	; Enable video interrupts 11101


	and.w   #%1111100011111111,sr				; 1111100011111111 => bits 8/9/10 = 0
	and.w   #$f8ff,sr
	.endif





main:
	move.l		DSP_flag_registres_YM_lus,d0
	cmp.l		#0,d0
	beq.s		main
	move.l		#0,DSP_flag_registres_YM_lus
	
	
	bsr		PLAYMUSIC

	lea		YM_registres_Coso,a6
	moveq		#0,d0
	move.b		8(a6),d0
	move.l		d0,GPU_volume_A
	move.b		9(a6),d0
	move.l		d0,GPU_volume_B
	move.b		10(a6),d0
	move.l		d0,GPU_volume_C


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


;-------------------------------------
;
;     COSO
;
;-------------------------------------
;----------------------------------------------------
YM_init_coso:
; tout le long de l'init D6=YM_nb_registres_par_frame



	moveq		#50,d0
	move.l		d0,YM_frequence_replay							; .w=frequence du replay ( 50 hz )


	rts



TIMER=0		;0=TIMER A,1=TIMER B,2=TIMER C,3=TIMER D
EQUALISEUR=1	;0=EQUALISEUR

TYPE=1			;1=MUSIQUE NORMALE,2=MUSIQUE DIGIT
PRG=0			;0=PRG,1=REPLAY BINAIRE
MONOCHROM=1		;0=REPLAY MONOCHROME,1=REPLAY COULEUR
PCRELATIF=1		;0=DIGIT PRES DU REPLAY,1=DIGIT LOIN DU REPLAY
AEI=0			;0=REPLAY MODE AEI,1=MODE SEI

CUTMUS=0		;0=INCLUT FIN MUSIQUE,1=ON NE PEUT COUPER LA MUSIQUE
DIGIT=1			;0=INCLUT REPLAY DIGIT,1=SANS
MMME=1			;0=INCLUT REPLAY MMME,1=SANS

TURRICAN=0		;0=REPLAY TURRICAN
OLD=1			;0=ANCIENNE VERSION,1=NOUVELLE



off22	equ		0					; rs.l	1	;ptr courant dans pattern								4
off0	equ		4					; rs.l	1	;ptr base patterns										4
off34	equ		8					; rs.w	1	;ptr fin musique										2

off4	equ		10					; rs.w	1	;ptr patterns (.W au lieu de .L)						2
offa	equ		12					; rs.l	1	;ptr base modulation volume								4
offe	equ		16					; rs.w	1	;ptr modulation volume (.W au lieu de .L)				2
off12	equ		18					; rs.l	1	;ptr base modulation fr‚quence							4
off30	equ		22					; rs.w	1	;ptr modulation fr‚quence (.W au lieu de .L)			2

off38	equ		24					; rs.l	1	;incr‚ment pour crescendo					4

off8	equ		28					; rs.b	1	;											1
off9	equ		29					; rs.b	1	;											1

off16	equ		30					; rs.b	1	;											1
off17	equ		31					; rs.b	1	;											1
off18	equ		32					; rs.b	1	;											1
off19	equ		33					; rs.b	1	;											1
off1a	equ		34					; rs.b	1	;											1
off1b	equ		35					; rs.b	1	;											1
off1c	equ		36					; rs.b	1	;											1
off1d	equ		37					; rs.b	1	;											1
off1e	equ		38					; rs.b	1	;											1
off1f	equ		39					; rs.b	1	;											1
off21	equ		40					; rs.b	1	;											1

off26	equ		41					; rs.b	1	;											1
off27	equ		42					; rs.b	1	;											1
off28	equ		43					; rs.b	1	;15-volume sonore de la voix				1
off2a	equ		44					; rs.b	1	;0,1 ou 2=type de son						1
off2b	equ		45					; rs.b	1	;											1
off2c	equ		46					; rs.b	1	;											1
off2d	equ		47					; rs.b	1	;volume sonore calculé						1
off2e	equ		48					; rs.b	1	;											1
;off3c	equ		47
off3c	equ		50

coso_envoi_registres:
	MOVEM.L			A0-A1,-(A7)
	LEA.L			PSGREG+2,A0											; = c177be
	lea		 		YM_registres_Coso,A1
	MOVE.B			(A0),(A1)+					; 0
	MOVE.B			4(A0),(A1)+					; 1
	MOVE.B			8(A0),(A1)+					; 2 
	MOVE.B			12(A0),(A1)+				; 3
	MOVE.B			16(A0),(A1)+				; 4
	MOVE.B			20(A0),(A1)+				; 5
	MOVE.B			24(A0),(A1)+				; 6
	MOVE.B			28(A0),(A1)+				; 7
	MOVE.B			32(A0),(A1)+				; 8
	MOVE.B			36(A0),(A1)+				; 9
	MOVE.B			40(A0),(A1)+				; A
	MOVEM.L 		(A7)+,A0-A1
	RTS


PLAYMUSIC:
	LEA	PSGREG(PC),A6
	TST.B	BLOQUEMUS-PSGREG(A6)
	BNE.S	L25A

	move.b	#$C0,$1E(A6)		;pour que ‡a tienne...

	SUBQ.B	#1,L80E-PSGREG(A6)
	BNE.S	L180
	MOVE.B	L810-PSGREG(A6),L80E-PSGREG(A6)
	MOVEQ	#0,D5
	LEA	voice0(PC),A0
	BSR.W	L25C
	LEA	voice1(PC),A0
	BSR.W	L25C
	LEA	voice2(PC),A0
	BSR.W	L25C
L180:
	LEA	voice0(PC),A0
	BSR	L39A
	move	d0,6(A6)
	MOVE.B	D0,2(A6)
	MOVE.B	D1,$22(A6)
	LEA	voice1(PC),A0
	BSR	L39A
	move	d0,$E(A6)
	MOVE.B	D0,$A(A6)
	MOVE.B	D1,$26(A6)
	LEA	voice2(PC),A0
	BSR	L39A
	move	D0,$16(A6)
	MOVE.B	D0,$12(A6)
	MOVE.B	D1,$2A(A6)

	;MOVEM.L	(A6),D0-D7/A0-A2
	;MOVEM.L	D0-D7/A0-A2,$FFFF8800.W
	bsr			coso_envoi_registres
L25A:	RTS

;
; calcule nouvelle note
;
L25C:	SUBQ.B	#1,off26(A0)
	BPL.S	L25A
	MOVE.B	off27(A0),off26(A0)
	MOVE.L	off22(A0),A1
L26C:	MOVE.B	(A1)+,D0
	CMP.B	#$FD,D0
	BLO.W	L308
	EXT	D0
	ADD	D0,D0
	JMP		COSO_CODEFD+(3*2)(PC,D0.W)
COSO_CODEFD:
	BRA.S	L2F4		;$FD
	BRA.S	L2E2		;$FE
				;$FF

; NOUVELLE VERSION
	move	off4(a0),d1
	cmp	off34(a0),d1
	blS.S	L288
	tst.b	off21(a0)		;nouveau replay !!!!
	bne.s	L288			;pour bien boucler !!!!
	clr	d1
	move	d5,off4+off3c(a0)
	move	d5,off4+(off3c*2)(a0)
L288:
	MOVE.L	off0(a0),a1
	add	d1,a1
	add	#$C,d1

	move	d1,off4(a0)

	MOVEQ	#0,D1
	move.b	(a1)+,D1
	move.b	(a1)+,off2c(A0)
	move.b	(a1)+,off16(A0)
	moveq	#$10,d0
	add.b	(a1)+,D0
	bcc.s	L2B4
	move.b	d0,off28(A0)		;F0-FF=volume … soustraire
	BRA.S	L2C4
L2B4:	add.b	#$10,d0
	bcc.S	L2C4
	move.B	d0,L810-PSGREG(A6)	;E0-EF=vitesse
L2C4:	ADD	D1,D1
	MOVE.L	L934(PC),A1
	ADD	$C+2(A1),D1
	ADD	(A1,D1.W),A1

	MOVE.L	A1,off22(A0)
	BRA.s	L26C

L2E2:
	MOVE.B	(A1)+,d0
	move.b	d0,off27(A0)
	MOVE.B	d0,off26(A0)
	BRA.s	L26C
L2F4:
	MOVE.B	(A1)+,d0
	move.b	d0,off27(A0)
	MOVE.B	d0,off26(A0)
	MOVE.L	A1,off22(A0)
	RTS

L308:	MOVE.B	D0,off8(a0)
	MOVE.B	(A1)+,D1
	MOVE.B	D1,off9(a0)
	AND	#$E0,D1			;d1=off9&$E0
	BEQ.S	.L31C
	MOVE.B	(A1)+,off1f(A0)
.L31C:	MOVE.L	A1,off22(A0)
	MOVE.L	D5,off38(A0)
	TST.B	D0
	BMI	L398
	MOVE.B	off9(a0),D0
	eor.b	d0,d1			;d1=off9&$1F
	ADD.B	off16(A0),D1

	MOVE.L	L934(PC),A1

	CMP	$26(A1),D1
	BLS.S	NOBUG2
;	CLR	D1
	move	$26(a1),d1
	move	#$700,$ffff8240.w
NOBUG2:
	ADD	D1,D1
	ADD	8+2(A1),D1
	ADD	(A1,D1.W),A1

	move	d5,offe(A0)
	MOVE.B	(a1)+,d1
	move.b	d1,off17(A0)
	MOVE.B	d1,off18(A0)
	MOVEQ	#0,D1
	MOVE.B	(a1)+,D1
	MOVE.B	(a1)+,off1b(A0)
;	MOVE.B	#$40,off2e(A0)
	clr.b	off2e(a0)
	MOVE.B	(a1)+,D2
	MOVE.B	D2,off1c(A0)
	MOVE.B	D2,off1d(A0)
	MOVE.B	(a1)+,off1e(A0)
	MOVE.L	a1,offa(A0)
	add.b	d0,d0			;test bit 6
	bpl.s	L37A
	MOVE.B	off1f(A0),D1
L37A:
	MOVE.L	L934(PC),A1
	CMP	$24(A1),D1
	BLS.S	NOBUG3
	move	$24(a1),d1
	move	#$070,$ffff8240.w
;	CLR	D1
NOBUG3:
	ADD	D1,D1

	ADD	4+2(A1),D1
	ADD	(A1,D1.W),A1

	MOVE.L	a1,off12(A0)
	move	d5,off30(A0)
	MOVE.B	D5,off1a(A0)
	MOVE.B	D5,off19(A0)
L398:	RTS

;
; calcul de la note … jouer
;
L39A:	MOVEQ	#0,D7
	MOVE	off30(a0),d6
L3A0:	TST.B	off1a(A0)
	BEQ.S	L3AE
	SUBQ.B	#1,off1a(A0)
	BRA	L4C01
L3AE:	MOVE.L	off12(A0),A1
	add	d6,a1
L3B6:	move.b	(a1)+,d0
	CMP.B	#$E0,D0
	BLO	L4B0
;	CMP.B	#$EA,D0		;inutile ???
;	BHS	L4B0

	EXT	D0
	ADD	#32,D0
	MOVE.B	COSO_CODES(PC,D0.W),D0
	JMP		BRANCH_COSO(PC,D0.W)

COSO_CODES:
	DC.B	E0-BRANCH_COSO
	DC.B	E1-BRANCH_COSO
	DC.B	E2-BRANCH_COSO
	DC.B	E3-BRANCH_COSO
	DC.B	E4-BRANCH_COSO
	DC.B	E5-BRANCH_COSO
	DC.B	E6-BRANCH_COSO
	DC.B	E7-BRANCH_COSO
	DC.B	E8-BRANCH_COSO
	DC.B	E9-BRANCH_COSO
	DC.B	EA-BRANCH_COSO
	EVEN
BRANCH_COSO:

BUG:	DCB.L	2,$4A780001
;	DCB.L	$100-$EA,$4A780001

E1:	BRA	L4C01
E0:
	moveq	#$3f,d6		;$E0
;clr d6 … pr‚sent !!!!
	and.B	(A1),D6
	BRA.S	L3AE
E2:
	clr	offe(a0)
	MOVE.B	#1,off17(A0)
	addq	#1,d6
	bra.s	L3B6

E9:
	;MOVE.B	#$B,$FFFF8800.W
	;move.b	(A1)+,$FFFF8802.W
	;move.l	#$0C0C0000,$FFFF8800.W
	;move.l	#$0D0D0A0A,$FFFF8800.W
	
	PEA			(A0)										; 00C0364E 4850                     PEA.L (A0)
	lea		 	YM_registres_Coso,A0			; 00C03650 207a 18fa                MOVEA.L (PC,$18fa) == $00c04f4c [00c0663e],A0
	MOVE.B 		(A1)+,$0B(A0)						; B=11				; 00C03654 1159 000b                MOVE.B (A1)+ [fd],(A0,$000b) == $00c051c9 [30]
	MOVE.B 		#$00,$0C(A0)					; C=12			; 00C03658 117c 0000 000c           MOVE.B #$00,(A0,$000c) == $00c051ca [3c]
	MOVE.B 		#$0a,$0D(A0)					; D=13			; 00C0365E 117c 000a 000d           MOVE.B #$0a,(A0,$000d) == $00c051cb [ac]
	MOVE.L 		(A7)+,A0									; 00C03664 205f                     MOVEA.L (A7)+ [00c0013e],A0
	
	addq	#2,d6
	bra.S	L3B6
E7:
	moveq	#0,d0
	move.b	(A1),D0
	ADD	D0,D0

	MOVE.L	L934(PC),A1
	ADD	4+2(A1),D0
	ADD	(A1,D0.W),A1

	MOVE.L	A1,off12(A0)
	clr	d6
	BRA	L3B6
EA:	move.b	#$20,off9(a0)
	move.b	(a1)+,off1f(a0)
	addq	#2,d6
	bra	L3B6
E8:	move.b	(A1)+,off1a(A0)
	addq	#2,d6
	BRA	L3A0

E4:	clr.b	off2a(A0)
	MOVE.B	(A1)+,d7
	addq	#2,d6
	BRA	L3B6		;4AE
E5:	MOVE.B	#1,off2a(A0)
	addq	#1,d6
	BRA	L3B6
E6:	MOVE.B	#2,off2a(A0)
	addq	#1,d6
	BRA	L3B6		;4AE

E3:	addq	#3,d6
	move.b	(A1)+,off1b(A0)
	move.b	(A1)+,off1c(A0)
	bra	L3B6		;nouveau

;L4AE:	move.b	(a1)+,d0
L4B0:
	MOVE.B	d0,off2b(A0)
	addq	#1,d6
L4C01:	move	d6,off30(a0)
;
; modulation volume
;
	move	offe(a0),d6
L4C0:	TST.B	off19(A0)
	BEQ.S	L4CC
	SUBQ.B	#1,off19(A0)
	BRA.S	L51A
L4CC:	SUBQ.B	#1,off17(A0)
	BNE.S	L51A
	MOVE.B	off18(A0),off17(A0)

	MOVE.L	offa(A0),A1
	add	d6,a1
	move.b	(A1)+,D0
	CMP.B	#$E0,D0
	BNE.S	L512
	moveq	#$3f,d6
; clr d6 … pr‚sent
	and.b	(A1),D6
	subq	#5,D6
	move.l	offa(a0),a1
	add	d6,a1
	move.b	(a1)+,d0
L512:
	CMP.B	#$E8,D0
	BNE.S	L4F4
	addq	#2,d6
	move.b	(A1)+,off19(A0)
	BRA.S	L4C0
L4F4:	CMP.B	#$E1,D0
	BEQ.S	L51A
	MOVE.B	d0,off2d(A0)
	addq	#1,d6
L51A:	move	d6,offe(a0)

	clr	d5
	MOVE.B	off2b(A0),D5
	BMI.S	L528
	ADD.B	off8(a0),D5
	ADD.B	off2c(A0),D5
L528:
	add.b	D5,D5
;	LEA	L94E(PC),A1
;	MOVE	(A1,d5.w),D0
	MOVE	L94E-PSGREG(A6,D5.W),D0

	move.b	off2a(A0),D1	;0,1 ou 2
	beq.S	L57E

	MOVE.B	off21(A0),D2
	ADDQ	#3,D2

	subq.b	#1,D1
	BNE.S	L578
	subq	#3,d2
	MOVE.B	off2b(A0),D7
	bclr	#7,d7
	bne.s	L578		;BMI impossible !!!
	add.b	off8(a0),d7
L578:

	BSET	D2,$1E(A6)
L57E:
	tst.b	d7
	BEQ.S	L594
	not.b	d7
	and.b	#$1F,D7
	MOVE.B	D7,$1A(A6)
L594:

	TST.B	off1e(A0)
	BEQ.S	L5A4
	SUBQ.B	#1,off1e(A0)
	BRA.S	L5FA
L5A4:
	clr	d2
	MOVE.B	off1c(A0),D2

;	bclr	#7,d2		;nouveau replay
;	beq.s	.ok		;BUG ????
;	add.b	d2,d2
;.ok

	clr	d1
	MOVE.B	off1d(A0),D1
	tst.b	off2e(a0)
	bmi.S	L5CE
	SUB.B	off1b(A0),D1
	BCC.S	L5DC
	tas	off2e(a0)	;ou bchg
	MOVEQ	#0,D1
	BRA.S	L5DC
L5CE:	ADD.B	off1b(A0),D1
	ADD.B	d2,d2
	CMP.B	d2,D1
	BCS.S	L5DA
	and.b	#$7f,off2e(a0)	;ou bchg
	MOVE.B	d2,D1
L5DA:	lsr.b	#1,d2
L5DC:	MOVE.B	D1,off1d(A0)
L5E0:
	sub	d2,D1

	ADD.B	#$A0,D5
	BCS.S	L5F8
	moveq	#$18,d2

	add	d1,d1
	add.b	d2,d5
	bcs.s	L5F8
	add	d1,d1
	add.b	d2,d5
	bcs.s	L5F8
	add	d1,d1
	add.b	d2,d5
	bcs.s	L5F8
	add	d1,d1
L5F8:	ADD	D1,D0
;;	EOR.B	#1,d6		;inutilis‚ !!!
;	MOVE.B	d6,off2e(A0)
L5FA:
	BTST	#5,off9(a0)
	BEQ.s	L628
	moveq	#0,D1
	MOVE.B	off1f(A0),D1
	EXT	D1
	swap	d1
	asr.l	#4,d1		;lsr.l #4,d1 corrige bug ???
	add.l	d1,off38(a0)
	SUB	off38(a0),D0
L628:
	MOVE.B	off2d(A0),D1

	;IFEQ	TURRICAN
	;SUB.B	off28(A0),D1
	;BPL.S	.NOVOL
	;CLR	D1
;.NOVOL:
	;RTS
	;ELSEIF
	MOVEQ	#-16,D2		;DEBUGGAGE VOLUME
	AND.B	D1,D2
	SUB.B	D2,D1
	SUB.B	off28(A0),D1
	BMI.S	.NOVOL
	OR.B	D2,D1
	RTS
.NOVOL:
	MOVE	D2,D1
	RTS
	;ENDC


LCA:


ZEROSND:
	clr.B	$22(A6)
	clr.B	$26(A6)
	clr.B	$2A(A6)
	MOVEM.L	$1C(A6),D0-D3
	MOVEM.L	D0-D3,$FFFF8800.W
	RTS

INITMUSIC:
;
; init musique
;
; entr‚e :
;	A0=pointe sur le texte 'COSO'
;	D0=num‚ro de la musique … jouer
;
	LEA	PSGREG(PC),A6
	ST	BLOQUEMUS-PSGREG(A6)

	subq	#1,d0
	BLT.S	LCA		;musique=0 -> cut mus



	;LEA		L51(PC),A1
	;MOVE.L	A1,MODIF1+2-PSGREG(A6)
	;LEA	flagdigit(PC),A1
	;MOVE.L	A1,MODIF2+2-PSGREG(A6)

	MOVE.L	A0,L934-PSGREG(A6)
	MOVE.L	$10(A0),A3
	ADD.L	A0,A3
	MOVE.L	$14(A0),A1
	ADD.L	A0,A1
;	ADD	D0,D0
;	ADD	D0,A1
;	ADD	D0,D0
	MULU	#6,D0
	ADD	D0,A1
	MOVEQ	#$C,D0
	MULU	(A1)+,D0	;PREMIER PATTERN
	MOVEQ	#$C,D2
	MULU	(A1)+,D2	;DERNIER PATTERN
	SUB	D0,D2

	ADD.L	D0,A3

	MOVE.B	1(A1),L810-PSGREG(A6)

	MOVEQ	#0,D0
	LEA	voice0(PC),A2
;
; REGISTRES UTILISES :
;
; D0=COMPTEUR VOIX 0-2
; D1=SCRATCH
; D2=PATTERN FIN
; A0={L934}
; A1=SCRATCH
; A2=VOICEX
; A3=PATTERN DEPART
; A6=BASE VARIABLES
;
L658:
	LEA	L7C6(PC),A1
	MOVE.L	A1,offa(A2)
	MOVE.L	A1,off12(A2)
	MOVEQ	#1,D1
	MOVE.B	D1,off17(A2)	;1
	MOVE.B	D1,off18(A2)	;1

	MOVE.B	d0,off21(A2)
	move.l	A3,off0(A2)
	move	D2,off34(A2)
	MOVE.B	#2,off2a(A2)

	moveq	#0,D1
	;IFEQ	OLD
	;MOVE	D1,off4(a2)
	;ELSEIF
	move	#$c,off4(A2)
	;ENDC

	MOVE	D1,offe(A2)
	MOVE.B	D1,off2d(A2)
	MOVE.B	D1,off8(A2)
	MOVE.B	D1,off9(A2)
	MOVE	D1,off30(A2)
	MOVE.B	D1,off19(A2)
	MOVE.B	D1,off1a(A2)
	MOVE.B	D1,off1b(A2)
	MOVE.B	D1,off1c(A2)
	MOVE.B	D1,off1d(A2)
	MOVE.B	D1,off1e(A2)
	MOVE.B	D1,off1f(A2)
	MOVE.L	D1,off38(A2)
	MOVE.B	D1,off26(A2)
	MOVE.B	D1,off27(A2)
	MOVE.B	D1,off2b(A2)

	move.b	(A3)+,D1
	ADD	D1,D1

	MOVE.L	A0,A1
	ADD	$C+2(A1),D1
	ADD	(A1,D1.W),A1

	MOVE.L	A1,off22(A2)
	move.b	(A3)+,off2c(A2)
	move.b	(A3)+,off16(A2)
	moveq	#$10,D1
	add.B	(A3)+,D1
	bcs.s	L712
	moveq	#0,D1
L712:
	MOVE.B	D1,off28(A2)
	lea	off3c(A2),A2
	ADDQ	#4,D2
	addq	#1,d0
	cmp	#3,d0
	blo	L658

	MOVE.B	#1,L80E-PSGREG(A6)
	;IFEQ	CUTMUS
;	CLR	BLOQUEMUS-PSGREG(A6)
	CLR.B	BLOQUEMUS-PSGREG(A6)
;	CLR.B	L813-PSGREG(A6)
	;ENDC
	RTS			;ou BRA ZEROSND

L7C6:	DC.B	1,0,0,0,0,0,0,$E1

PSGREG:	
	DC.W	$0000,$0000,$101,$0000
	DC.W	$0202,$0000,$303,$0000
	DC.W	$0404,$0000,$505,$0000
	DC.W	$0606,$0000,$707,$FFFF
	DC.W	$0808
	DC.W	$0000,$909,$0000
	DC.W	$0A0A,$0000

L94E:	DC.W	$EEE,$E17,$D4D,$C8E
	DC.W	$BD9,$B2F,$A8E,$9F7
	DC.W	$967,$8E0,$861,$7E8
	DC.W	$777,$70B,$6A6,$647
	DC.W	$5EC,$597,$547,$4FB
	DC.W	$4B3,$470,$430,$3F4
	DC.W	$3BB,$385,$353,$323
	DC.W	$2F6,$2CB,$2A3,$27D
	DC.W	$259,$238,$218,$1FA
	DC.W	$1DD,$1C2,$1A9,$191
	DC.W	$17B,$165,$151,$13E
	DC.W	$12C,$11C,$10C,$FD
	DC.W	$EE,$E1,$D4,$C8
	DC.W	$BD,$B2,$A8,$9F
	DC.W	$96,$8E,$86,$7E
	DC.W	$77,$70,$6A,$64
	DC.W	$5E,$59,$54,$4F
	DC.W	$4B,$47,$43,$3F
	DC.W	$3B,$38,$35,$32
	DC.W	$2F,$2C,$2A,$27
	DC.W	$25,$23,$21,$1F
	DC.W	$1D,$1C,$1A,$19
	DC.W	$17,$16,$15,$13
	DC.W	$12,$11,$10,$F
; amiga=C178a8
L80E:	DC.B	4
L810:	DC.B	4
	;IFEQ	CUTMUS
BLOQUEMUS:DC.B	-1
	;ENDC



	EVEN
voice0:	ds.B	off3c
voice1:	ds.B	off3c
voice2:	ds.B	off3c
L934:	DC.L	0


	

;-------------------------------------
;
;    FIN COSO
;
;-------------------------------------




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

		.if		1=0
; synchro avec l'interrupt object list
		movefa	R26,R26
		
GPU_boucle_wait_vsync2:
		movefa	R26,R25
		cmp		R25,R26
		jr		eq,GPU_boucle_wait_vsync2
		nop
		.endif
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


; -------------------------------
; scrolling
; -------------------------------

; coder le scrolling
;  font = 320*256
;  1 caractere = 32*32
; 	Y scrolling = 164
; vitesse = 4 pixels par vbl

		movei	#GPU_scrolling__pointeur_sur_lettre_en_cours,R13
		movei	#GPU_scrolling__position_dans_la_lettre_en_cours,R10
		load	(R13),R16
		load	(R10),R0
		movei	#GPU__gestion_scrolling__pas_de_nouvelle_lettre,R27
		cmpq	#0,R0
		jump	ne,(R27)
		nop
		
		movei	#GPU_scrolling__position_dans_le_texte_du_scrolling,R11
		movei	#fin_texte_scrolling,R12
		load	(R11),R1
		addq	#1,R1
		cmp		R12,R1
		jr		ne,GPU__gestion_scrolling__pas_fin_de_texte
		nop
		movei	#texte_scrolling,R1
GPU__gestion_scrolling__pas_fin_de_texte:
		loadb	(R1),R2			; R2 = nouvelle lettre
		store	R1,(R11)
		subq	#32,R2
		moveq	#10,R4
		move	R2,R3
		movei	#(scrolling__hauteur_de_lettre*320),R6				; taille d'une ligne dans la fonte
		div		R4,R2			; emplacement de lettre / 10
		movei	#font_replicants,R16
		move	R2,R5
		mult	R4,R5			; x 10
		sub		R5,R3			; reste sur 10
		; R2 = ligne, R3 = colonne
		mult	R6,R2
		shlq	#5,R3			; x32
		add		R2,R16
		add		R3,R16			; R16 pointe sur la lettre
		store	R16,(R13)		; stocke le pointeur sur la lettre

GPU__gestion_scrolling__pas_de_nouvelle_lettre:
; il faut remplir 4 pixels x 32 dans le buffer
; en utilisant GPU_scrolling__offset_actuel_sur_le_buffer
; zone_scroller
; 
		movei	#GPU_scrolling__offset_actuel_sur_le_buffer,R21
		add		R0,R16			; pointe sur la colonne de lettre a copier
		
		movei	#zone_scroller,R20
		movei	#320*2*2,R4				; = 1 ligne de buffer
		load	(R21),R22				; R22 = offset dans le buffer
		movei	#320,R3					; = 1 ligne de fonte
		move	R22,R23					; R23 = offset 2eme partie du buffer
		move	R22,R24					; sauvegarde l'offset
		add		R3,R23					; => 2eme partie du buffer
		add		R20,R24					; + #zone_scroller
		add		R3,R23					; => 2eme partie du buffer
		movei	#scrolling__hauteur_de_lettre,R7			; compteur de lignes a copier
		add		R20,R23					; + #zone_scroller

		movei	#table_couleur_logo__conversion,R5

		subq	#8,R4				; 1280-8 pour passage ligne suivante
		subq	#4,R3
		
		movei	#GPU__gestion_scrolling__boucle_copie_pixels,R27

GPU__gestion_scrolling__boucle_copie_pixels:
; multiple de 4
; blitter blitter...	
; ne pas utiliser R0
		.rept	4
		loadb	(R16),R2			; numero couleur 256
		move	R5,R6				; table des couleurs
		add		R2,R2				; *2 pour avoir une valeur 16 bits
		addq	#1,R16
		add		R2,R6
		loadw	(R6),R8				; R8 = couleur 16 bits
		storew	R8,(R24)
		storew	R8,(R23)
		addq	#2,R24
		addq	#2,R23
		.endr
		
		
	
		add		R3,R16
		add		R4,R24		
		add		R4,R23
		;add		#(320*2)-4,R24 / R23
		;add		#320-4,R16

		subq	#1,R7
		jump	ne,(R27)
		nop
; avancer offset actuel
; avancer position dans la lettre

		addq	#4,R3		; R3=320


		movei	#32,R2
		addq	#4,R0		; GPU_scrolling__position_dans_la_lettre_en_cours + 4 
		or		R0,R0
		cmp		R2,R0
		jr		ne,GPU__gestion_scrolling__pas_fin_de_la_lettre
		nop
		moveq	#0,R0
GPU__gestion_scrolling__pas_fin_de_la_lettre:
		store	R0,(R10)
		
		
		add		R3,R3			; R3=320*2
		
		addq	#8,R22
		cmp		R3,R22				; R3=320
		jr		ne,GPU__gestion_scrolling__pas_fin_du_buffer
		nop
		moveq	#0,R22
GPU__gestion_scrolling__pas_fin_du_buffer:
		store	R22,(R21)			; => GPU_scrolling__offset_actuel_sur_le_buffer




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



;-----------------
; inserer sprites scrolling
; le pointeur sur le buffer doit etre multiple de 8
; utiliser FIRSTPIX en bits 49-54 : 4*8 = 32

		movei	#GPU_scrolling__offset_actuel_sur_le_buffer,R2
		movei	#zone_scroller,R13
;edz		
		;movei	#font_replicants+(320*32*2),R13
		
		
		load	(r2),R0
		
		movei	#(1<<15)+(%0100),R4								; TRANS = 1 ( <<15 ) + 6 bits de iwidth
		;movei	#(3<<12)+(1<<15)+((640/8)<<18)+(%0111<<28),R2		; 4 bits de iwidth << 28		; depth=3 256 couleurs  / Pitch=1 / DWIDTH=1 / IWIDTH=0  : 4<<12 + 0<<15 + 0<<18 + 1<<28 : $4000 + $10000000

; version 16 bits par pixel
		movei	#(4<<12)+(1<<15)+((1280/8)<<18)+(%1100<<28),R2		; 4 bits de iwidth << 28		; depth=4 16 bits couleurs  / Pitch=1 / DWIDTH=1 / IWIDTH=0  : 4<<12 + 0<<15 + 0<<18 + 1<<28 : $4000 + $10000000
; edz
		;movei	#(3<<12)+(1<<15)+((320/8)<<18)+(%0111<<28),R2		; 4 bits de iwidth << 28		; depth=3 256 couleurs  / Pitch=1 / DWIDTH=1 / IWIDTH=0  : 4<<12 + 0<<15 + 0<<18 + 1<<28 : $4000 + $10000000

;edz	
		
		add		R0,R13

		addq		#8,R13
		


		movei	#scrolling__position_Y_a_l_ecran,R12				; R12=Y
; edz
		;movei	#0,R12
		movei	#largeur_bande_gauche-14,R11				; R11=X
		
		add		R9,R12				; Y + ligne du haut/1ere ligne
		sharq	#3,R13				; DATA sur phrase
		movei	#32,R14				; R14=height
; edz
		;movei	#256,R14
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
		store	R3,(R18)		; bits 32-63
		addq	#4,R18
		store	R1,(R18)
		addq	#4,R18




; -----
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



;-------------------------------------
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

; scrolling
GPU_scrolling__position_dans_la_lettre_en_cours:		dc.l		0
GPU_scrolling__position_dans_le_texte_du_scrolling:		dc.l		texte_scrolling
GPU_scrolling__pointeur_sur_lettre_en_cours:			dc.l		0
GPU_scrolling__offset_actuel_sur_le_buffer:				dc.l		0
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






;-------------------------------------
;
;     DSP
;
;-------------------------------------

	.phrase
YM_DSP_debut:

	.dsp
	.org	D_RAM
DSP_base_memoire:

; CPU interrupt
	.rept	8
		nop
	.endr
; I2S interrupt
	movei	#DSP_LSP_routine_interruption_I2S,r28						; 6 octets
	movei	#D_FLAGS,r30											; 6 octets
	jump	(r28)													; 2 octets
	load	(r30),r29	; read flags								; 2 octets = 16 octets
; Timer 1 interrupt
	movei	#DSP_LSP_routine_interruption_Timer1,r12						; 6 octets
	movei	#D_FLAGS,r16											; 6 octets
	jump	(r12)													; 2 octets
	load	(r16),r13	; read flags								; 2 octets = 16 octets
; Timer 2 interrupt	
	movei	#DSP_LSP_routine_interruption_Timer2,r28						; 6 octets
	movei	#D_FLAGS,r30											; 6 octets
	jump	(r28)													; 2 octets
	load	(r30),r29	; read flags								; 2 octets = 16 octets
; External 0 interrupt
	.rept	8
		nop
	.endr
; External 1 interrupt
	.rept	8
		nop
	.endr













; -------------------------------
; DSP : routines en interruption
; -------------------------------
DSP_LSP_routine_interruption_I2S:
;-------------------------------------------------------------------------------------------------
;
; routine de replay, fabrication des samples
; bank 0 : 
; R28/R29/R30/R31
; +
; R18/R19/R20/R21/R22/R23/R24/R25/R26/R27
;
;-------------------------------------------------------------------------------------------------
; R28/R29/R30/R31 : utilisé par l'interruption

; - calculer le prochain noise : 0 ou $FFFF
; - calculer le prochain volume enveloppe
; - un canal = ( mixer

;		bt = ((((yms32)posA)>>31) | mixerTA) & (bn | mixerNA);
; (onde carrée normale OU mixerTA ) ET ( noise OU mixerNA ) 

;		vol  = (*pVolA)&bt;
;		volume ( suivant le pointeur, enveloppe ou fixe) ET mask du dessus
; - increment des positions apres : position A B C, position noise, position enveloppe

; mask = (mixerTA OR Tone calculé par frequence) AND ( mixerNA OR
; avec Tone calculé = FFFFFFFF bit 31=1 : bit 31 >> 31 = 1 : NEG 1 = -1

	.if		DSP_DEBUG
; change la couleur du fond
	movei	#$777,R26
	movei	#BG,r27
	storew	r26,(r27)
	.endif

	

;--------------------------
; gerer l'enveloppe
; - incrementer l'offset enveloppe
; partie entiere 16 bits : virgule 16 bits
; partie entiere and %1111 = position dans la sous partie d'enveloppe
; ( ( partie entiere >> 4 ) and %1 ) << 2 = pointeur sur la sous partie d'enveloppe


; si positif, limiter, masquer, à 11111 ( 5 bits:16 )

	movei	#YM_DSP_pointeur_enveloppe_en_cours,R24
	load	(R24),R24						; R24=pointeur sur la liste de 3 pointeur de sequence d'enveloppe : -1,0,1 : [ R24+(R25 * 4) ] + (R27*4)

YM_DSP_replay_sample_gere_env:
	movei	#YM_DSP_increment_enveloppe,R27
	movei	#YM_DSP_offset_enveloppe,R26
	load	(R27),R27
	load	(R26),R25				; R25 = offset en cours enveloppe
	add		R27,R25					; offset+increment 16:16
	
	move	R25,R23
	sharq	#16,R23					; on vire la virgule, on garde le signe
	moveq	#%1111,R21
	move	R23,R27
	and		R21,R27					; R27=partie entiere de l'offset AND 1111 = position dans la sous partie d'enveloppe
	

	sharq	#4,R23					; offset / 16, on garde le signe
	jr		mi, YM_DSP_replay_sample_offset_env_negatif
	moveq	#%1,R21
	movei	#$0FFFFFFF,R22
	and		R22,R25					; valeur positive : on limite la valeur pour ne pas qu'elle redevienne négative
	and		R21,R23					; R25 = pointeur sur la sous partie d'enveloppe
	
YM_DSP_replay_sample_offset_env_negatif:
	store	R25,(R26)				; sauvegarde YM_DSP_offset_enveloppe

	add		R23,R23					; R23*2 = partie entiere %1
	add		R27,R27					; R27*2
	add		R23,R23					; R23*4
	add		R27,R27					; R27*4
	
	add		R23,R24					; R24 = pointeur sur la partie d'enveloppe actuelle : R24+(R25 * 4) 
	load	(R24),R24				; R24 = pointeur sur la partie d'enveloppe actuelle :  [ R24+(R25 * 4) ]
	movei	#YM_DSP_volE,R26
	add		R27,R24					; [ R24+(R25 * 4) ] + (R27*4)
	load	(R24),R24				; R24 = volume actuel enveloppe
	or		R24,R24
	store	R24,(R26)				; volume de l'enveloppe => YM_DSP_volE


;--------------------------
; gérer le noise
; on avance le step de noise
; 	si on a 16 bits du haut>0 => on genere un nouveau noise
; 	et on masque le bas avec $FFFF
; l'increment de frequence du Noise est en 16:16

	movei	#YM_DSP_increment_Noise,R27
	movei	#YM_DSP_position_offset_Noise,R26
	movei	#YM_DSP_current_Noise_mask,R22
	load	(R27),R27
	load	(R26),R24
	load	(R22),R18			; R18 = current mask Noise
	add		R27,R24
	move	R24,R23
	shrq	#16,R23				; R23 = partie entiere, à zéro ?
	movei	#YM_DSP_replay_sample_pas_de_generation_nouveau_Noise,R20
	cmpq	#0,R23
	jump	eq,(R20)
	nop
; il faut generer un nouveau noise
; il faut masquer R24 avec $FFFF
	movei	#$FFFF,R23
	and		R23,R24				; YM_DSP_position_offset_Noise, juste virgule

	.if		DSP_random_Noise_generator_method=1
; generer un nouveau pseudo random methode 1
	MOVEI	#YM_DSP_current_Noise, R23		
	LOAD	(R23), R21			
	MOVEQ	#$01, R20			
	MOVE	R21, R27			
	MOVE	R21, R25			
	SHRQ	#$02, R25			
	AND		R20, R27			
	AND		R20, R25			
	XOR		R27, R25			
	MOVE	R21, R27			
	MOVE	R25, R20			
	SHRQ	#$01, R27			
	SHLQ	#$10, R20			
	OR		R27, R20			
	STORE	R20, (R23)	
	.endif

	.if		DSP_random_Noise_generator_method=2
; does not work !
; generer un nouveau pseudo random methode 2 : seed = seed * 1103515245 + 12345;
	MOVEI	#YM_DSP_Noise_seed, R23		
	LOAD	(R23), R21			
	movei	#1103515245,R20
	mult	R20,R21
	or		R21,R21
	movei	#12345,R27
	add		R27,R21
	STORE	R21, (R23)	
	.endif

	.if		DSP_random_Noise_generator_method=3
; wyhash16 : https://lemire.me/blog/2019/07/03/a-fast-16-bit-random-number-generator/
	MOVEI	#YM_DSP_Noise_seed, R23	
	movei	#$fc15,R20
	LOAD	(R23), R21
	add		R20,R21
	movei	#$2ab,R20
	mult	R20,R21
	move	R21,R25
	rorq	#16,R21
	xor		R25,R21
	store	R21,(R23)
	.endif

	.if		DSP_random_Noise_generator_method=4
; generer un nouveau pseudo random LFSR YM : https://www.smspower.org/Development/YM2413ReverseEngineeringNotes2018-05-13
	MOVEI	#YM_DSP_current_Noise, R23		
	LOAD	(R23), R21
	
	moveq	#1,R27
	move	R21,R20
	and		R27,R20				; 	bool output = state & 1;

	shrq	#1,R21				; 	state >>= 1;
	
	cmpq	#0,R20
	jr		eq,YM_DSP_replay_sample_LFSR_bit_0_egal_0
	
	nop
	movei	#$400181,R20
	xor		R20,R21
	
YM_DSP_replay_sample_LFSR_bit_0_egal_0:
	store	R21,(R23)
	.endif

; calcul masque 
	MOVEQ	#$01,R20
	and		R20,R21			; on garde juste le bit 0
	sub		R20,R21			; 0-1= -1 / 1-1=0 => mask sur 32 bits
	or		R21,R21
	store	R21,(R22)		; R21=>YM_DSP_current_Noise_mask
	move	R21,R18

YM_DSP_replay_sample_pas_de_generation_nouveau_Noise:
; en entrée : R24 = offset noise, R18 = current mask Noise

	store	R24,(R26)			; R24=>YM_DSP_position_offset_Noise


;---- ====> R18 = mask current Noise ----


;--------------------------
; ----- gerer digidrum A
	movei	#YM_DSP_pointeur_sample_digidrum_voie_A,R27					; pointeur << 21 + 11 bits de virgule 21:11
	load	(R27),R26
	movei	#YM_DSP_replay_sample_pas_de_digidrums_voie_A,R24
	cmpq	#0,R26
	jump	eq,(R24)
	nop

	move	R26,R24
	shrq	#YM_DSP_precision_virgule_digidrums,R24				; partie entiere du pointeur sample DG

	loadb	(R24),R23			; R23=sample DG sur 4 bits : de 0 a 15
	movei	#YM_DSP_table_de_volumes,R25
	shlq	#2,R23				; * 4 
	add		R23,R25
	movei	#YM_DSP_volA,R22
	movei	#YM_DSP_pointeur_sur_source_du_volume_A,R24
	load	(R25),R23
	store	R22,(R24)
	store	R23,(R22)			; volume du sample DG
	
	movei	#YM_DSP_increment_sample_digidrum_voie_A,R25				; increment << 21 + 11 bits de virgule 21:11
	movei	#YM_DSP_pointeur_fin_sample_digidrum_voie_A,R24
	load	(R25),R25
	load	(R24),R24					; pointeur de fin 21:11
	add		R25,R26						; pointeur + increment 21:11
	cmp		R24,R26
	jr		mi,YM_DSP_replay_DG_pas_fin_de_sample_voie_A
	nop
	moveq	#0,R26
YM_DSP_replay_DG_pas_fin_de_sample_voie_A:
	store	R26,(R27)			; YM_DSP_pointeur_sample_digidrum_voie_A

YM_DSP_replay_sample_pas_de_digidrums_voie_A:


; ----- gerer digidrum B
	movei	#YM_DSP_pointeur_sample_digidrum_voie_B,R27					; pointeur << 21 + 11 bits de virgule 21:11
	load	(R27),R26
	movei	#YM_DSP_replay_sample_pas_de_digidrums_voie_B,R24
	cmpq	#0,R26
	jump	eq,(R24)
	nop

	move	R26,R24
	shrq	#YM_DSP_precision_virgule_digidrums,R24				; partie entiere du pointeur sample DG

	loadb	(R24),R23			; R23=sample DG sur 4 bits : de 0 a 15
	movei	#YM_DSP_table_de_volumes,R25
	shlq	#2,R23				; * 4 
	add		R23,R25
	movei	#YM_DSP_volB,R22
	movei	#YM_DSP_pointeur_sur_source_du_volume_B,R24
	load	(R25),R23
	store	R22,(R24)
	store	R23,(R22)			; volume du sample DG
	
	movei	#YM_DSP_increment_sample_digidrum_voie_B,R25				; increment << 21 + 11 bits de virgule 21:11
	movei	#YM_DSP_pointeur_fin_sample_digidrum_voie_B,R24
	load	(R25),R25
	load	(R24),R24					; pointeur de fin 21:11
	add		R25,R26						; pointeur + increment 21:11
	cmp		R24,R26
	jr		mi,YM_DSP_replay_DG_pas_fin_de_sample_voie_B
	nop
	moveq	#0,R26
YM_DSP_replay_DG_pas_fin_de_sample_voie_B:
	store	R26,(R27)			; YM_DSP_pointeur_sample_digidrum_voie_B

YM_DSP_replay_sample_pas_de_digidrums_voie_B:


; ----- gerer digidrum C
	movei	#YM_DSP_pointeur_sample_digidrum_voie_C,R27					; pointeur << 21 + 11 bits de virgule 21:11
	load	(R27),R26
	movei	#YM_DSP_replay_sample_pas_de_digidrums_voie_C,R24
	cmpq	#0,R26
	jump	eq,(R24)
	nop

	move	R26,R24
	shrq	#YM_DSP_precision_virgule_digidrums,R24				; partie entiere du pointeur sample DG

	loadb	(R24),R23			; R23=sample DG sur 4 bits : de 0 a 15
	movei	#YM_DSP_table_de_volumes,R25
	shlq	#2,R23				; * 4 
	add		R23,R25
	movei	#YM_DSP_volC,R22
	movei	#YM_DSP_pointeur_sur_source_du_volume_C,R24
	load	(R25),R23
	store	R22,(R24)
	store	R23,(R22)			; volume du sample DG
	
	movei	#YM_DSP_increment_sample_digidrum_voie_C,R25				; increment << 21 + 11 bits de virgule 21:11
	movei	#YM_DSP_pointeur_fin_sample_digidrum_voie_C,R24
	load	(R25),R25
	load	(R24),R24					; pointeur de fin 21:11
	add		R25,R26						; pointeur + increment 21:11
	cmp		R24,R26
	jr		mi,YM_DSP_replay_DG_pas_fin_de_sample_voie_C
	nop
	moveq	#0,R26
YM_DSP_replay_DG_pas_fin_de_sample_voie_C:
	store	R26,(R27)			; YM_DSP_pointeur_sample_digidrum_voie_C

YM_DSP_replay_sample_pas_de_digidrums_voie_C:



;---- ====> R18 = mask current Noise ----
;--------------------------
; gérer les voies A B C 
; ---------------


; canal A

	movei	#YM_DSP_Mixer_NA,R26

	move	R18,R24				; R24 = on garde la masque du current Noise

	load	(R26),R26			; YM_DSP_Mixer_NA
	or		R26,R18				; YM_DSP_Mixer_NA OR Noise
; R18 = Noise OR mask du registre 7 de mixage du Noise A


	movei	#YM_DSP_increment_canal_A,R27
	movei	#YM_DSP_position_offset_A,R26
	load	(R27),R27
	load	(R26),R25
		
	add		R27,R25
	store	R25,(R26)							; YM_DSP_position_offset_A
	shrq	#31,R25
	neg		R25									; 0 devient 0, 1 devient -1 ($FFFFFFFF)
	
; R25 = onde carrée A

	movei	#YM_DSP_Mixer_TA,R26
	load	(R26),R26
	or		R26,R25
; R25 = onde carrée A OR mask du registre 7 de mixage Tone A


; Noise AND Tone

	movei	#YM_DSP_pointeur_sur_source_du_volume_A,R26
	and		R18,R25					; R25 = Noise and Tone

	load	(R26),R27				; R20 = pointeur sur la source de volume pour le canal A
	load	(r27),R20				; R20=volume pour le canal A 0 à 32767
	
	;movei	#pointeur_buffer_de_debug,R26
	;load	(R26),R18
	;store	R20,(R18)
	;addq	#4,R18
	;store	R18,(R26)
	;nop
	
	
	and		R25,R20					; R20=volume pour le canal A
; R20 = sample canal A



; ---------------
; canal B
	movei	#YM_DSP_Mixer_NB,R26
	move	R24,R18				; R24 = masque du current Noise
	
	load	(R26),R26
	or		R26,R18

; R18 = Noise OR mask du registre 7 de mixage du Noise B

	movei	#YM_DSP_increment_canal_B,R27
	movei	#YM_DSP_position_offset_B,R26
	load	(R27),R27
	load	(R26),R25
	add		R27,R25
	or		R25,R25
	store	R25,(R26)							; YM_DSP_position_offset_B
	shrq	#31,R25
	neg		R25									; 0 devient 0, 1 devient -1 ($FFFFFFFF)
; R25 = onde carrée B

	movei	#YM_DSP_Mixer_TB,R26
	load	(R26),R26
	or		R26,R25
; R25 = onde carrée B OR mask du registre 7 de mixage Tone B

; Noise AND Tone

	movei	#YM_DSP_pointeur_sur_source_du_volume_B,R23
	and		R18,R25					; R25 = Noise and Tone
	load	(R23),R23				; R23 = pointeur sur la source de volume pour le canal B
	load	(r23),R23				; R23=volume pour le canal B 0 à 32767
	and		R25,R23					; R23=volume pour le canal B
; R23 = sample canal B

; ---------------
; canal C
	movei	#YM_DSP_Mixer_NC,R26
	move	R24,R18				; R24 = masque du current Noise
	
	load	(R26),R26
	or		R26,R18

; R18 = Noise OR mask du registre 7 de mixage du Noise C

	movei	#YM_DSP_increment_canal_C,R27
	movei	#YM_DSP_position_offset_C,R26
	load	(R27),R27
	load	(R26),R25
	add		R27,R25
	or		R25,R25
	store	R25,(R26)							; YM_DSP_position_offset_B
	shrq	#31,R25
	neg		R25									; 0 devient 0, 1 devient -1 ($FFFFFFFF)
; R25 = onde carrée C

	movei	#YM_DSP_Mixer_TC,R26
	load	(R26),R26
	or		R26,R25
; R25 = onde carrée B OR mask du registre 7 de mixage Tone C

; Noise AND Tone

	movei	#YM_DSP_pointeur_sur_source_du_volume_C,R22
	and		R18,R25					; R25 = Noise and Tone
	load	(R22),R22				; R23 = pointeur sur la source de volume pour le canal B
	load	(r22),R22				; R23=volume pour le canal B 0 à 32767
	and		R25,R22					; R23=volume pour le canal B
; R22 = sample canal C

; sans stereo : R20=A / R23=B / R22=C / R21=//

; mono desactivé
	.if		STEREO=0
	shrq	#1,R20					; quand volume maxi = 32767
	;shrq	#1,R21					; quand volume maxi = 32767
	shrq	#1,R23
	shrq	#1,R22
	add		R23,R20					; R20 = R20=canal A + R23=canal B
	;add		R21,R20					; R20 = R20=canal A + R23=canal B + R21=canal D
	movei	#32768,R27
	add		R22,R20					; + canal C
	movei	#L_I2S,r26
	sub		R27,R20					; resultat signé sur 16 bits
	movei	#L_I2S+4,r24
	store	r20,(r26)				; write right channel
	store	r20,(r24)				; write left channel
	.endif

	
	.if		STEREO=1

	movei	#YM_DSP_Voie_A_pourcentage_Droite,R24
	move	R20,R26					; R26=A
	mult	R24,R26
	shrq	#STEREO_shit_bits,R26
	
	movei	#YM_DSP_Voie_B_pourcentage_Droite,R24
	move	R23,R25					; R27=B
	mult	R24,R25
	shrq	#STEREO_shit_bits,R25
	
	movei	#YM_DSP_Voie_C_pourcentage_Droite,R24
	move	R22,R18					; R18=C
	mult	R24,R18
	shrq	#STEREO_shit_bits,R18

	add		R26,R25					; R27=A+B

	movei	#YM_DSP_Voie_D_pourcentage_Droite,R24
	move	R21,R26					; R26=D
	mult	R24,R26
	shrq	#STEREO_shit_bits,R26
	
	add		R18,R25
	add		R26,R25					; R25=droite


	movei	#YM_DSP_Voie_A_pourcentage_Gauche,R24
	mult	R24,R20
	shrq	#STEREO_shit_bits,R20
	
	movei	#YM_DSP_Voie_B_pourcentage_Gauche,R24
	mult	R24,R23
	shrq	#STEREO_shit_bits,R23
	
	movei	#YM_DSP_Voie_C_pourcentage_Gauche,R24
	mult	R24,R22
	shrq	#STEREO_shit_bits,R22

	add		R20,R23					; R23=A+B

	movei	#YM_DSP_Voie_D_pourcentage_Gauche,R24
	mult	R24,R21
	shrq	#STEREO_shit_bits,R21

	movei	#32768,R27
	
	add		R22,R23
	add		R21,R23					; R23=gauche

	sub		R27,R25
	movei	#L_I2S,r26
	sub		R27,R23
	movei	#L_I2S+4,r24

	store	r25,(r26)				; write right channel
	store	r23,(r24)				; write left channel

	.endif

	.if		DSP_DEBUG
; change la couleur du fond
	movei	#$000,R26
	movei	#BG,r27
	storew	r26,(r27)
	.endif

;------------------------------------	
; return from interrupt I2S
	load	(r31),r28	; return address
	bset	#10,r29		; clear latch 1 = I2S
	;bset	#11,r29		; clear latch 1 = timer 1
	;bset	#12,r29		; clear latch 1 = timer 2
	bclr	#3,r29		; clear IMASK
	addq	#4,r31		; pop from stack
	addqt	#2,r28		; next instruction
	jump	t,(r28)		; return
	store	r29,(r30)	; restore flags




















;--------------------------------------------
; ---------------- Timer 1 ------------------
;--------------------------------------------
; autorise interruptions, pour timer I2S
	.if		I2S_during_Timer1=1
	bclr	#3,r13		; clear IMASK
	store	r13,(r16)	; restore flags
	.endif

DSP_LSP_routine_interruption_Timer1:
	.if		DSP_DEBUG_T1
; change la couleur du fond
	movei	#$077,R1
	movei	#BG,r0
	loadw	(r0),r1
	addq	#$1,r1
	storew	r1,(r0)
	.endif


;-------------------------------------------------------------------------------------------------
; -------------------------------------------------------------------------------
; routine de lecture des registres YM
; bank 0 : 
 ; gestion timer deplacé sur :
; R12(R28)/R13(R29)/R16(R30)
; +
; R0/R1/R2/R3/R4/R5/R6/R7/R8/R9/R10/R11 + R14
; -------------------------------------------------------------------------------
	;-------------------------------------------------------------------------------------------------
; COSO = 11+3 registres
	movei		#YM_registres_Coso,R1
	moveq		#1,R8



; round(  ((freq_YM / 16) / frequence_replay) * 65536) /x;	
; 
; registres 0+1 = frequence voie A
	loadb		(R1),R2						; registre 0
	add			R8,R1
	loadb		(R1),R3						; registre 1
	movei		#%1111,R7
	add			R8,R1


	and			R7,R3
	movei		#YM_frequence_predivise,R5
	shlq		#8,R3
	load		(R5),R5
	add			R2,R3						; R3 = frequence YM canal A

	move		R5,R6
	
	div			r3,R5
	or			R5,R5
	shlq		#16,R5
	
	movei		#YM_DSP_increment_canal_A,R2
	store		R5,(R2)

; registres 2+3 = frequence voie B
	loadb		(R1),R2						; registre 2
	add			R8,R1
	loadb		(R1),R3						; registre 3
	add			R8,R1

	and			R7,R3
	shlq		#8,R3
	move		R6,R5						; R5=YM_frequence_predivise
	add			R2,R3						; R3 = frequence YM canal B
	
	div			r3,R5
	or			R5,R5
	shlq		#16,R5
	
	movei		#YM_DSP_increment_canal_B,R2
	store		R5,(R2)
	
; registres 4+5 = frequence voie C
	loadb		(R1),R2						; registre 4
	add			R8,R1
	loadb		(R1),R3						; registre 5
	add			R8,R1

	and			R7,R3
	shlq		#8,R3
	move		R6,R5						; R5=YM_frequence_predivise
	add			R2,R3						; R3 = frequence YM canal C
	
	div			r3,R5
	or			R5,R5
	shlq		#16,R5
	
	movei		#YM_DSP_increment_canal_C,R2
	store		R5,(R2)
	
; registre 6
; 5 bit noise frequency
	loadb		(R1),R2						; registre 6
	movei		#%11111,R7
	add			R8,R1
	
	and			R7,R2						; on ne garde que 5 bits
	jr			ne,DSP_lecture_registre6_pas_zero
	move		R6,R5						; R5=YM_frequence_predivise

	moveq		#1,R2
DSP_lecture_registre6_pas_zero:
	
	movei		#YM_DSP_increment_Noise,R3
	div			R2,R5
	or			R5,R5
	; shlq		#15,R5						; on laisse l'increment frequence Noise sur 16(entier):16(virgule)
	store		R5,(R3)

; registre 7 
; 6 bits interessants
;	Noise	 Tone
;	C B A    C B A
	loadb		(R1),R2						; registre 7
	add			R8,R1


; bit 0 = Tone A
	move		R2,R4
	moveq		#%1,R3
	and			R3,R4					; 0 ou 1
	movei		#YM_DSP_Mixer_TA,R5
	;subq		#1,R4					; 0=>-1 / 1=>0 
	neg			R4						; 0=>0 / 1=>-1
	shlq		#1,R3					; bit suivant
	store		R4,(R5)

; bit 1 = Tone B
	move		R2,R4
	movei		#YM_DSP_Mixer_TB,R5
	and			R3,R4					; 0 ou 1
	shrq		#1,R4
	;subq		#1,R4					; 0=>-1 / 1=>0 
	neg			R4						; 0=>0 / 1=>-1
	shlq		#1,R3					; bit suivant
	store		R4,(R5)

; bit 2 = Tone C
	move		R2,R4
	movei		#YM_DSP_Mixer_TC,R5
	and			R3,R4					; 0 ou 1
	shrq		#2,R4
	;subq		#1,R4					; 0=>-1 / 1=>0 
	neg			R4						; 0=>0 / 1=>-1
	shlq		#1,R3					; bit suivant
	store		R4,(R5)
	
; bit 3 = Noise A
	move		R2,R4
	movei		#YM_DSP_Mixer_NA,R5
	and			R3,R4					; 0 ou 1
	shrq		#3,R4
	;subq		#1,R4					; 0=>-1 / 1=>0 
	neg			R4						; 0=>0 / 1=>-1
	shlq		#1,R3					; bit suivant
	store		R4,(R5)
	
; bit 4 = Noise B
	move		R2,R4
	movei		#YM_DSP_Mixer_NB,R5
	and			R3,R4					; 0 ou 1
	shrq		#4,R4
	neg			R4						; 0=>0 / 1=>-1
	;subq		#1,R4					; 0=>-1 / 1=>0 
	shlq		#1,R3					; bit suivant
	store		R4,(R5)
	
; bit 5 = Noise C
	move		R2,R4
	movei		#YM_DSP_Mixer_NC,R5
	and			R3,R4					; 0 ou 1
	shrq		#5,R4
	neg			R4						; 0=>0 / 1=>-1
;	subq		#1,R4					; 0=>-1 / 1=>0 
	shlq		#1,R3					; bit suivant
	store		R4,(R5)
	

	movei		#YM_DSP_table_de_volumes,R14

; registre 8 = volume canal A
; B4=1 bit =M / M=0=>volume fixe / M=1=>volume enveloppe
; B3/B2/B1/B0 = volume fixe pour le canal A
;	Noise	 Tone
;	C B A    C B A
	loadb		(R1),R2						; registre 8
	add			R8,R1	

	move		R2,R4
	movei		#YM_DSP_registre8,R6
	moveq		#%1111,R3
	store		R4,(R6)					; sauvegarde la valeur de volume sur 16, pour DG
	movei		#YM_DSP_volE,R5
	and			R3,R4
	
	shlq		#2,R4					; volume sur 16 *4 
	load		(R14+R4),R4

	movei		#YM_DSP_volA,R6
	store		R4,(R6)

	movei		#YM_DSP_pointeur_sur_source_du_volume_A,R3
	btst		#4,R2					; test bit M : M=0 => volume contenu dans registre 8 / M=1 => volume d'env
	jr			ne,DSP_lecture_registre8_pas_volume_A
	nop
	
	move		R6,R5
	
DSP_lecture_registre8_pas_volume_A:
	store		R5,(R3)


; registre 9 = volume canal B
; B4=1 bit =M / M=0=>volume fixe / M=1=>volume enveloppe
; B3/B2/B1/B0 = volume fixe pour le canal B
;	Noise	 Tone
;	C B A    C B A
	loadb		(R1),R2						; registre 9
	add			R8,R1	

	move		R2,R4
	movei		#YM_DSP_registre9,R6
	moveq		#%1111,R3
	store		R4,(R6)					; sauvegarde la valeur de volume sur 16, pour DG
	movei		#YM_DSP_volE,R5
	and			R3,R4

	shlq		#2,R4					; volume sur 16 *4 
	load		(R14+R4),R4

	movei		#YM_DSP_volB,R6
	store		R4,(R6)

	movei		#YM_DSP_pointeur_sur_source_du_volume_B,R3

	btst		#4,R2
	jr			ne,DSP_lecture_registre9_pas_env
	nop
	
	move		R6,R5
	
DSP_lecture_registre9_pas_env:
	store		R5,(R3)

; registre 10 = volume canal C
; B4=1 bit =M / M=0=>volume fixe / M=1=>volume enveloppe
; B3/B2/B1/B0 = volume fixe pour le canal C
;	Noise	 Tone
;	C B A    C B A
	loadb		(R1),R2						; registre 10
	add			R8,R1	

	move		R2,R4
	movei		#YM_DSP_registre10,R6
	moveq		#%1111,R3
	store		R4,(R6)					; sauvegarde la valeur de volume sur 16, pour DG
	movei		#YM_DSP_volE,R5
	and			R3,R4
	
	shlq		#2,R4					; volume sur 16 *4 
	load		(R14+R4),R4
	
	movei		#YM_DSP_volC,R6
	store		R4,(R6)

	movei		#YM_DSP_pointeur_sur_source_du_volume_C,R3

	btst		#4,R2
	jr			ne,DSP_lecture_registre10_pas_env
	nop

	move		R6,R5
	
DSP_lecture_registre10_pas_env:
	store		R5,(R3)



; registre 11 & 12 = frequence de l'enveloppe sur 16 bits
	loadb		(R1),R2						; registre 11 = 8 bits du bas
	add			R8,R1
	loadb		(R1),R3						; registre 12 = 8 bits du haut

	movei		#YM_frequence_predivise,R5
	add			R8,R1
	shlq		#8,R3
	load		(R5),R5						; R5=YM_frequence_predivise
	add			R2,R3						; R3 = frequence YM canal B

	jr			ne,DSP_lecture_registre11_12_pas_zero
	nop
	moveq		#0,R5
	jr			DSP_lecture_registre11_12_zero
	nop
	
DSP_lecture_registre11_12_pas_zero:	
	div			r3,R5

DSP_lecture_registre11_12_zero:	
	movei		#YM_DSP_increment_enveloppe,R2
	or			R5,R5
	store		R5,(R2)


; registre 13 = envelop shape
	loadb		(R1),R2						; registre 13 = Envelope shape control

	movei		#YM_DSP_registre13,R6

	add			R8,R1

	store		R2,(R6)					; sauvegarde la valeur env shape registre 13

; tester si bit 7 = 1 => ne pas modifier l'env en cours

	movei		#DSP_lecture_registre13_pas_env,R3
	btst		#7,R2
	jump		ne,(R3)
	nop

; - choix de la bonne enveloppe
	sub			R8,R1
	bset		#7,R2
	storeb		R2,(R1)
	add			R8,R1
	
	
	moveq		#%1111,R5
	movei		#$FFF00000,R3						; 16 bits du haut = -16, virgule = 0
	and			R5,R2
	movei		#YM_DSP_offset_enveloppe,R5
	movei		#YM_DSP_pointeur_enveloppe_en_cours,R0
	store		R3,(R5)
	movei		#YM_DSP_liste_des_enveloppes,R4
	shlq		#2,R2								; numero d'env dans registre 13 * 4
	add			R2,R4
	load		(R4),R4
	store		R4,(R0)								; pointe sur enveloppe

DSP_lecture_registre13_pas_env:


	.if		1=0
; ----------------
; registre R11 = flag effets sur les voies : A=bit 0, B=bit 1, C=bit 2, bit 3=buzzer , bit 4=Sinus Sid
	movei	#YM_flag_effets_sur_les_voies,R11
	load	(R11),R11

;--------------------------------
; gestion des effets par voie
; ------- effet sur voie A ?
	;movei		#YM_flag_effets_voie_A,R3
	;load		(R3),R3
	movei		#DSP_lecture_registre_effet_voie_A_pas_d_effet,R4
	;cmpq		#0,R3
	btst		#0,R11
	jump		eq,(R4)
	
	loadb		(R1),R2						; octet 1 effet sur la voie : 8 bits du haut = index prediv ( sur 3 bits 0-7 )
	add			R8,R1
	loadb		(R1),R3						; octet 2 effet sur la voie : 8 bits du bas = diviseur
	add			R8,R1

	movei		#DSP_lecture_registre_effet_voie_A_pas_de_DG,R4
	btst		#7,R2
	jump		eq,(R4)

;--------------------------------
; digidrums sur la voie A
;--------------------------------
	moveq		#%111,R5
	movei		#YM_DSP_table_prediviseur,R6
	and			R5,R2						; 3 bits de R2 = prediviseur
	shlq		#2,R2						; * 4 
	add			R2,R6
	load		(R6),R6						; R6=prediviseur
	
	mult		R6,R3						; R3=prediviseur * diviseur
	movei		#YM_DSP_frequence_MFP,R5
	div			R3,R5						; frequence du MFP / ( prediviseur * diviseur )
	movei		#DSP_frequence_de_replay_reelle_I2S,R4
	load		(R4),R4
	or			R5,R5
	shlq		#YM_DSP_precision_virgule_digidrums,R5
	div			R4,R5						; R5=increment digidrum=(frequence du MFP / ( prediviseur * diviseur ) ) / frequence_de_replay_reelle_I2S en 16:16
	movei		#YM_DSP_table_digidrums,R3
	movei		#YM_DSP_registre8,R6
	load		(R6),R6
	shlq		#3,R6						; numero sample * 8
	add			R6,R3						; pointe sur pointeur sample + pointeur fin de sample
	load		(R3),R2						; R2=pointeur debut sample DG en 21:11
	movei		#YM_DSP_pointeur_sample_digidrum_voie_A,R6
	addq		#4,R3
	load		(R3),R4						; R4=pointeur fin sample DG en 21:11
	store		R2,(R6)						; stocke debut sample DG en 21:11
	addq		#4,R6						; passe au pointeur de fin du sample
	store		R4,(R6)						; stocke fin sample DG en 21:11
	addq		#4,R6						; passe au pointeur de fin du sample
	store		R5,(R6)						; stocke increment sample DG en 21:11

; force volume sur volA, mixerTA et mixerNA = $FFFFFFFF
	movei		#YM_DSP_pointeur_sur_source_du_volume_A,R3
	movei		#-1,R2
	movei		#YM_DSP_volA,R5
	movei		#YM_DSP_Mixer_NA,R4
	store		R5,(R3)
	movei		#YM_DSP_Mixer_TA,R7
	store		R2,(R4)
	movei		#DSP_lecture_registre_effet_voie_A_pas_d_effet,R3
	store		R2,(R7)
	
	jump		(R3)		; saute par dessus la routine SID
	nop
	
; numero sample DG = registre 8
; R2 and 11 bits = frequence de replay : table de frequence mfp -$400 : 
; stop, no function executed		: 256 valeurs = 0
; subdivider divides by 4
; subdivider divides by 10
; subdivider divides by 16
; subdivider divides by 16
; subdivider divides by 50
; subdivider divides by 64
; subdivider divides by 100
; subdivider divides by 200
;
; ( 2457600 / DSP_frequence_de_replay_reelle_I2S ) / prediv (4/10/16/16/50/64/100/200) / valeur sur 8 bits
; => ( 2457600 / DSP_frequence_de_replay_reelle_I2S ) (précalcumé) / ( prediv * valeur )
; mfpPrediv[8] = {0,4,10,16,50,64,100,200};
; premiere valeur = index prediv ( sur 3 bits 0-7 )
; deuxieme valeur = diviseur

DSP_lecture_registre_effet_voie_A_pas_de_DG:

DSP_lecture_registre_effet_voie_A_pas_d_effet:

; -----------------------------
; ------- effet sur voie B ?

;	movei		#YM_flag_effets_voie_B,R3
;	load		(R3),R3
	movei		#DSP_lecture_registre_effet_voie_B_pas_d_effet,R4
	;cmpq		#0,R3
	btst		#1,R11
	jump		eq,(R4)
	
	loadb		(R1),R2						; octet 1 effet sur la voie : 8 bits du haut = index prediv ( sur 3 bits 0-7 )
	add			R8,R1
	loadb		(R1),R3						; octet 2 effet sur la voie : 8 bits du bas = diviseur
	add			R8,R1

	movei		#DSP_lecture_registre_effet_voie_B_pas_de_DG,R4
	btst		#7,R2
	jump		eq,(R4)
; digidrums sur la voie B
	moveq		#%111,R5
	movei		#YM_DSP_table_prediviseur,R6
	and			R5,R2						; 3 bits de R2 = prediviseur
	shlq		#2,R2						; * 4 
	add			R2,R6
	load		(R6),R6						; R6=prediviseur
	
	mult		R6,R3						; R3=prediviseur * diviseur
	movei		#YM_DSP_frequence_MFP,R5
	div			R3,R5						; frequence du MFP / ( prediviseur * diviseur )
	movei		#DSP_frequence_de_replay_reelle_I2S,R4
	load		(R4),R4
	or			R5,R5
	shlq		#YM_DSP_precision_virgule_digidrums,R5
	div			R4,R5						; R5=increment digidrum=(frequence du MFP / ( prediviseur * diviseur ) ) / frequence_de_replay_reelle_I2S en 16:16
	movei		#YM_DSP_table_digidrums,R3
	movei		#YM_DSP_registre9,R6
	load		(R6),R6
	shlq		#3,R6						; numero sample * 8
	add			R6,R3						; pointe sur pointeur sample + pointeur fin de sample
	load		(R3),R2						; R2=pointeur debut sample DG en 21:11
	movei		#YM_DSP_pointeur_sample_digidrum_voie_B,R6
	addq		#4,R3
	load		(R3),R4						; R4=pointeur fin sample DG en 21:11
	store		R2,(R6)						; stocke debut sample DG en 21:11
	addq		#4,R6						; passe au pointeur de fin du sample
	store		R4,(R6)						; stocke fin sample DG en 21:11
	addq		#4,R6						; passe au pointeur de fin du sample
	store		R5,(R6)						; stocke increment sample DG e: 21:11

; force volume sur volB, mixerTB et mixerNB = $FFFFFFFF
	movei		#YM_DSP_pointeur_sur_source_du_volume_B,R3
	movei		#-1,R2
	movei		#YM_DSP_volB,R5
	movei		#YM_DSP_Mixer_NB,R4
	store		R5,(R3)
	movei		#YM_DSP_Mixer_TB,R7
	store		R2,(R4)
	movei		#DSP_lecture_registre_effet_voie_B_pas_d_effet,R3
	store		R2,(R7)
	
	jump		(R3)		; saute par dessus la routine SID
	nop

DSP_lecture_registre_effet_voie_B_pas_de_DG:
DSP_lecture_registre_effet_voie_B_pas_d_effet:



; -----------------------------
; ------- effet sur voie C ?
	;movei		#YM_flag_effets_voie_C,R3
	;load		(R3),R3
	movei		#DSP_lecture_registre_effet_voie_C_pas_d_effet,R4
	;cmpq		#0,R3
	btst		#2,R11
	jump		eq,(R4)
	
	loadb		(R1),R2						; octet 1 effet sur la voie : 8 bits du haut = index prediv ( sur 3 bits 0-7 )
	add			R8,R1
	loadb		(R1),R3						; octet 2 effet sur la voie : 8 bits du bas = diviseur
	add			R8,R1

	movei		#DSP_lecture_registre_effet_voie_C_pas_de_DG,R4
	btst		#7,R2
	jump		eq,(R4)
; digidrums sur la voie C
	moveq		#%111,R5
	
	
	movei		#YM_DSP_table_prediviseur,R6
	and			R5,R2						; 3 bits de R2 = prediviseur
	shlq		#2,R2						; * 4 
	add			R2,R6
	load		(R6),R6						; R6=prediviseur
	
	mult		R6,R3						; R3=prediviseur * diviseur
	movei		#YM_DSP_frequence_MFP,R5
	div			R3,R5						; frequence du MFP / ( prediviseur * diviseur )
	movei		#DSP_frequence_de_replay_reelle_I2S,R4
	load		(R4),R4
	or			R5,R5
	shlq		#YM_DSP_precision_virgule_digidrums,R5
	div			R4,R5						; R5=increment digidrum=(frequence du MFP / ( prediviseur * diviseur ) ) / frequence_de_replay_reelle_I2S en 16:16
	movei		#YM_DSP_table_digidrums,R3
	movei		#YM_DSP_registre10,R6
	load		(R6),R6
	shlq		#3,R6						; numero sample * 8
	add			R6,R3						; pointe sur pointeur sample + pointeur fin de sample
	load		(R3),R2						; R2=pointeur debut sample DG en 21:11
	movei		#YM_DSP_pointeur_sample_digidrum_voie_C,R6
	addq		#4,R3
	load		(R3),R4						; R4=pointeur fin sample DG en 21:11
	store		R2,(R6)						; stocke debut sample DG en 21:11
	addq		#4,R6						; passe au pointeur de fin du sample
	store		R4,(R6)						; stocke fin sample DG en 21:11
	addq		#4,R6						; passe au pointeur de fin du sample
	store		R5,(R6)						; stocke increment sample DG en 21:11

; force volume sur volC, mixerTC et mixerNC = $FFFFFFFF
	movei		#YM_DSP_pointeur_sur_source_du_volume_C,R3
	movei		#-1,R2
	movei		#YM_DSP_volC,R5
	movei		#YM_DSP_Mixer_NC,R4
	store		R5,(R3)
	movei		#YM_DSP_Mixer_TC,R7
	store		R2,(R4)
	movei		#DSP_lecture_registre_effet_voie_C_pas_d_effet,R3
	store		R2,(R7)
	
	jump		(R3)		; saute par dessus la routine SID
	nop	

DSP_lecture_registre_effet_voie_C_pas_de_DG:
DSP_lecture_registre_effet_voie_C_pas_d_effet:


	.endif

;---> precalculer les valeurs qui ne bougent pas pendant 1 VBL entiere	

; debug raz pointeur buffer debug
	;movei		#pointeur_buffer_de_debug,R0
	;movei		#buffer_de_debug,R1
	;store		R1,(R0)	
	;nop

; reading coso registers is done
	movei	#DSP_flag_registres_YM_lus,R2
	moveq	#1,R0
	store	R0,(R2)


	movei	#vbl_counter_replay_DSP,R0
	load	(R0),R1
	addq	#1,R1
	store	R1,(R0)
	
	.if		DSP_DEBUG_T1
; change la couleur du fond
	movei	#$000,R0
	movei	#BG,R1
	;storew	R0,(R1)
	.endif

;------------------------------------	
; return from interrupt Timer 1
	load	(r31),r12	; return address
	;bset	#10,r29		; clear latch 1 = I2S
	bset	#11,r13		; clear latch 1 = timer 1
	;bset	#12,r29		; clear latch 1 = timer 2
	bclr	#3,r13		; clear IMASK
	addq	#4,r31		; pop from stack
	addqt	#2,r12		; next instruction
	jump	t,(r12)		; return
	store	r13,(r16)	; restore flags


; ------------------- N/A ------------------
DSP_LSP_routine_interruption_Timer2:
; ------------------- N/A ------------------













; ----------------------------------------------
; routine d'init du DSP
; registres bloqués par les interruptions : R29/R30/R31 ?
DSP_routine_init_DSP:
; assume run from bank 1
	movei	#DSP_ISP+(DSP_STACK_SIZE*4),r31			; init isp
	moveq	#0,r1
	moveta	r31,r31									; ISP (bank 0)
	movei	#DSP_USP+(DSP_STACK_SIZE*4),r31			; init usp
	
; -------------------------------------------------------------------------------
; calcul de la frequence prédivisee pour le YM
; ((YM_frequence_YM2149/16)*65536)/DSP_Audio_frequence

	movei	#YM_frequence_YM2149,r0
	shlq	#16-4-2,r0					; /16 puis * 65536
	
	movei	#DSP_frequence_de_replay_reelle_I2S,r2
	load	(r2),r2
	
	div		r2,r0
	or		r0,r0					; attente fin de division
	shlq	#2,r0					; ramene a *65536

	
	movei	#YM_frequence_predivise,r1
	store	r0,(r1)



;calcul de ( 1<<31) / frequence de replay réelle )

	moveq	#1,R0
	shlq	#31,R0
	div		r2,r0
	or		R0,R0
	
	movei	#DSP_UN_sur_frequence_de_replay_reelle_I2S,r1
	store	R0,(R1)



; init I2S
	movei	#SCLK,r10
	movei	#SMODE,r11
	movei	#DSP_parametre_de_frequence_I2S,r12
	movei	#%001101,r13			; SMODE bascule sur RISING
	load	(r12),r12				; SCLK
	store	r12,(r10)
	store	r13,(r11)

; init Timer 1

	movei	#182150,R10				; 26593900 / 146 = 182150
	movei	#YM_frequence_replay,R11
	load	(R11),R11
	or		R11,R11
	div		R11,R10
	or		R10,R10
	move	R10,R13
	
	subq	#1,R13					; -1 pour parametrage du timer 1
	
	

; 26593900 / 50 = 531 878 => 2 × 73 × 3643 => 146*3643
	movei	#JPIT1,r10				; F10000
	;movei	#JPIT2,r11				; F10002
	movei	#146-1,r12				; Timer 1 Pre-scaler
	;movei	#3643-1,r13				; Timer 1 Divider  
	
	shlq	#16,r12
	or		R13,R12
	
	store	r12,(r10)				; JPIT1 & JPIT2


; init timer 2

;	movei	#JPIT3,r10				; F10004
;	movei	#JPIT4,r11				; F10006



; enable interrupts
	movei	#D_FLAGS,r28
	
	movei	#D_I2SENA|D_TIM1ENA|REGPAGE,r29			; I2S+Timer 1
	
	;movei	#D_TIM1ENA|REGPAGE,r29					; Timer 1 only
	;movei	#D_I2SENA|REGPAGE,r29					; I2S only
	;movei	#D_TIM2ENA|REGPAGE,r29					; Timer 2 only
	
	store	r29,(r28)



DSP_boucle_centrale:
	movei	#DSP_boucle_centrale,R20
	jump	(R20)
	nop

	


	.phrase


; datas DSP
DSP_flag_registres_YM_lus:			dc.l			0

vbl_counter_replay_DSP:				dc.l			0
YM_DSP_pointeur_sur_table_des_pointeurs_env_Buzzer:		dc.l		0

YM_DSP_registre8:			dc.l			0
YM_DSP_registre9:			dc.l			0
YM_DSP_registre10:			dc.l			0
YM_DSP_registre13:			dc.l			0

DSP_frequence_de_replay_reelle_I2S:					dc.l			0
DSP_UN_sur_frequence_de_replay_reelle_I2S:			dc.l			0
DSP_parametre_de_frequence_I2S:						dc.l			0

YM_DSP_increment_canal_A:			dc.l			0
YM_DSP_increment_canal_B:			dc.l			0
YM_DSP_increment_canal_C:			dc.l			0
YM_DSP_increment_Noise:				dc.l			0
YM_DSP_increment_enveloppe:			dc.l			0

YM_DSP_Mixer_TA:					dc.l			0
YM_DSP_Mixer_TB:					dc.l			0
YM_DSP_Mixer_TC:					dc.l			0
YM_DSP_Mixer_NA:					dc.l			0
YM_DSP_Mixer_NB:					dc.l			0
YM_DSP_Mixer_NC:					dc.l			0

YM_DSP_volA:					dc.l			$1234
YM_DSP_volB:					dc.l			$1234
YM_DSP_volC:					dc.l			$1234

YM_DSP_volE:					dc.l			0
YM_DSP_offset_enveloppe:		dc.l			0
YM_DSP_pointeur_enveloppe_en_cours:	dc.l		0

YM_DSP_pointeur_sur_source_du_volume_A:				dc.l		YM_DSP_volA
YM_DSP_pointeur_sur_source_du_volume_B:				dc.l		YM_DSP_volB
YM_DSP_pointeur_sur_source_du_volume_C:				dc.l		YM_DSP_volC

YM_DSP_position_offset_A:		dc.l			0
YM_DSP_position_offset_B:		dc.l			0
YM_DSP_position_offset_C:		dc.l			0

YM_DSP_position_offset_Noise:	dc.l			0
YM_DSP_current_Noise:			dc.l			$12071971
YM_DSP_current_Noise_mask:		dc.l			0
YM_DSP_Noise_seed:				dc.l			$12071971


; variables DG
YM_DSP_pointeur_sample_digidrum_voie_A:				dc.l		0
YM_DSP_pointeur_fin_sample_digidrum_voie_A:			dc.l		0
YM_DSP_increment_sample_digidrum_voie_A:			dc.l		0

YM_DSP_pointeur_sample_digidrum_voie_B:				dc.l		0
YM_DSP_pointeur_fin_sample_digidrum_voie_B:			dc.l		0
YM_DSP_increment_sample_digidrum_voie_B:			dc.l		0

YM_DSP_pointeur_sample_digidrum_voie_C:				dc.l		0
YM_DSP_pointeur_fin_sample_digidrum_voie_C:			dc.l		0
YM_DSP_increment_sample_digidrum_voie_C:			dc.l		0


YM_DSP_table_de_volumes:
	dc.l				0,161,265,377,580,774,1155,1575,2260,3088,4570,6233,9330,13187,21220,32767
; table volumes Amiga:
	;dc.l				$00*$c0, $00*$c0, $00*$c0, $00*$c0, $01*$c0, $02*$c0, $02*$c0, $04*$c0, $05*$c0, $08*$c0, $0B*$c0, $10*$c0, $18*$c0, $22*$c0, $37*$c0, $55*$c0
	
; volume 4 bits en 8 bits
; $00 $00 $00 $00 $01 $02 $02 $04 $05 $08 $0B $10 $18 $22 $37 $55
; ramené à 16383 ( 65535 / 4)
; *$c0

	;dc.l				0,161/2,265/2,377/2,580/2,774/2,1155/2,1575/2,2260/2,3088/2,4570/2,6233/2,9330/2,13187/2,21220/2,32767/2

					; 62,161,265,377,580,774,1155,1575,2260,3088,4570,6233,9330,13187,21220,32767



YM_DSP_table_prediviseur:
	dc.l		0,4,10,16,50,64,100,200	

; flags pour nb octets à lire
YM_flag_effets_sur_les_voies:			dc.l				0
YM_flag_effets_voie_A:		dc.l		0
YM_flag_effets_voie_B:		dc.l		0
YM_flag_effets_voie_C:		dc.l		0


PSG_compteur_frames_restantes:			dc.l		0
YM_pointeur_actuel_ymdata:				dc.l		0

; - le registre 13 definit la forme de l'enveloppe
; - on initialise une valeur à -16
; partie entiere 16 bits : virgule 16 bits
; partie entiere and %1111 = position dans la sous partie d'enveloppe
; ( ( partie entiere >> 4 ) and %1 ) << 2 = pointeur sur la sous partie d'enveloppe


YM_DSP_forme_enveloppe_1:
; enveloppe montante
	dc.l				62,161,265,377,580,774,1155,1575,2260,3088,4570,6233,9330,13187,21220,32767
; table volumes Amiga:
	;dc.l				$00*$c0, $00*$c0, $00*$c0, $00*$c0, $01*$c0, $02*$c0, $02*$c0, $04*$c0, $05*$c0, $08*$c0, $0B*$c0, $10*$c0, $18*$c0, $22*$c0, $37*$c0, $55*$c0

YM_DSP_forme_enveloppe_2:
; enveloppe descendante
	dc.l				32767,21220,13187,9330,6233,4570,3088,2260,1575,1155,774,580,377,265,161,62
; table volumes Amiga:
	;dc.l				$55*$c0, $37*$c0, $22*$c0, $18*$c0,$10*$c0,$0B*$c0,$08*$c0, $05*$c0,$04*$c0,$02*$c0,$02*$c0,$01*$c0,$00*$c0,$00*$c0,$00*$c0,$00*$c0

YM_DSP_forme_enveloppe_3:
; enveloppe zero
	dc.l				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
YM_DSP_forme_enveloppe_4:
; enveloppe a 1
; table volumes Amiga:
	;dc.l				$55*$c0, $55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0,$55*$c0
	dc.l				32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767,32767

;-- formes des enveloppes
; forme enveloppe  0 0 x x
	dc.l		YM_DSP_forme_enveloppe_2	
YM_DSP_enveloppe00xx:
YM_DSP_enveloppe1001:
	dc.l		YM_DSP_forme_enveloppe_3,YM_DSP_forme_enveloppe_3
; forme enveloppe  0 1 x x
	dc.l		YM_DSP_forme_enveloppe_1	
YM_DSP_enveloppe01xx:
	dc.l		YM_DSP_forme_enveloppe_3,YM_DSP_forme_enveloppe_3
; forme enveloppe  1 0 0 0
	dc.l		YM_DSP_forme_enveloppe_2	
YM_DSP_enveloppe1000:
	dc.l		YM_DSP_forme_enveloppe_2,YM_DSP_forme_enveloppe_2
; forme enveloppe  1 0 0 1 = forme enveloppe  0 0 x x
; forme enveloppe  1 0 1 0
	dc.l		YM_DSP_forme_enveloppe_2	
YM_DSP_enveloppe1010:
	dc.l		YM_DSP_forme_enveloppe_1,YM_DSP_forme_enveloppe_2
; forme enveloppe  1 0 1 1
	dc.l		YM_DSP_forme_enveloppe_2
YM_DSP_enveloppe1011:
	dc.l		YM_DSP_forme_enveloppe_4,YM_DSP_forme_enveloppe_4
; forme enveloppe  1 1 0 0
	dc.l		YM_DSP_forme_enveloppe_1
YM_DSP_enveloppe1100:
	dc.l		YM_DSP_forme_enveloppe_1,YM_DSP_forme_enveloppe_1
; forme enveloppe  1 1 0 1
	dc.l		YM_DSP_forme_enveloppe_1
YM_DSP_enveloppe1101:
	dc.l		YM_DSP_forme_enveloppe_4,YM_DSP_forme_enveloppe_4
; forme enveloppe  1 1 1 0
	dc.l		YM_DSP_forme_enveloppe_1
YM_DSP_enveloppe1110:
	dc.l		YM_DSP_forme_enveloppe_2,YM_DSP_forme_enveloppe_1
; forme enveloppe  1 1 1 1
	dc.l		YM_DSP_forme_enveloppe_1
YM_DSP_enveloppe1111:
	dc.l		YM_DSP_forme_enveloppe_3,YM_DSP_forme_enveloppe_3

YM_DSP_liste_des_enveloppes:
	dc.l		YM_DSP_enveloppe00xx, YM_DSP_enveloppe00xx, YM_DSP_enveloppe00xx , YM_DSP_enveloppe00xx
	dc.l		YM_DSP_enveloppe01xx,YM_DSP_enveloppe01xx,YM_DSP_enveloppe01xx,YM_DSP_enveloppe01xx
	dc.l		YM_DSP_enveloppe1000,YM_DSP_enveloppe1001,YM_DSP_enveloppe1010,YM_DSP_enveloppe1011
	dc.l		YM_DSP_enveloppe1100,YM_DSP_enveloppe1101,YM_DSP_enveloppe1110,YM_DSP_enveloppe1111


; digidrums
; en memoire DSP
YM_DSP_table_digidrums:
	.rept		16			; maxi 16 digidrums
		dc.l		0			; pointeur adresse du sample
		dc.l		0			; pointeur fin du sample 
	.endr

	.phrase	


;---------------------
; FIN DE LA RAM DSP
YM_DSP_fin:
;---------------------


SOUND_DRIVER_SIZE			.equ			YM_DSP_fin-DSP_base_memoire
	.print	"--- Sound driver code size (DSP): ", /u SOUND_DRIVER_SIZE, " bytes / 8192 ---"




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
table_couleur_logo__conversion:
		dc.w	0000
CLUT_RGB:
;1
	dc.w		(%00111<<11)+(%00000<<1)+(00<<6)			;0100		1
	dc.w		(%01011<<11)+(%00000<<1)+(00<<6)			;0200		2
	dc.w		(%01111<<11)+(%00000<<1)+(00<<6)			;0300		3
	dc.w		(%10011<<11)+(%00000<<1)+(00<<6)			;0400		4
	dc.w		(%10111<<11)+(%00000<<1)+(00<<6)			;0500		5
	dc.w		(%11011<<11)+(%00111<<1)+(00<<6)			;0610		6
	dc.w		(%11111<<11)+(%00111<<1)+(00<<6)			;0710		7
	dc.w		(%11111<<11)+(%01011<<1)+(00<<6)			;0720		8
	dc.w		(%11111<<11)+(%01011<<1)+(%00111<<6)		;0721		9
	dc.w		(%11111<<11)+(%01111<<1)+(%00111<<6)		;0731		10
	dc.w		(%11111<<11)+(%01111<<1)+(%01011<<6)		;0732
	dc.w		(%11111<<11)+(%10011<<1)+(%01011<<6)		;0742
	dc.w		(%11111<<11)+(%10011<<1)+(%01111<<6)		;0743
	dc.w		(%11111<<11)+(%10111<<1)+(%01111<<6)		;0753
	dc.w		(%11111<<11)+(%10111<<1)+(%10011<<6)		;0754
	dc.w		(%11111<<11)+(%11011<<1)+(%10011<<6)		;0764
	dc.w		(%11111<<11)+(%11011<<1)+(%10111<<6)		;0765
	dc.w		(%11111<<11)+(%11011<<1)+(%11011<<6)		;0766
	dc.w		(%11111<<11)+(%11111<<1)+(%11111<<6)		;0777		19
;20	
;nb couleurs : 40
table_couleur_logo:
;        dc.w    $0000
        dc.w    $1084				; 20
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
        dc.w    $C717			; 50
        dc.w    $C71F
        dc.w    $C720
        dc.w    $C727
        dc.w    $C728
        dc.w    $BF27
        dc.w    $DF2F
        dc.w    $E730
        dc.w    $E731			; 58
; 60	
; +50 couleurs font
        dc.w    $0000			;
        dc.w    $0500			; 60
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
        dc.w    $E230
        dc.w    $E338
        dc.w    $E438
        dc.w    $E538
        dc.w    $E638
        dc.w    $DEF8
        dc.w    $C738
        dc.w    $A738
        dc.w    $8738
        dc.w    $5EB8
        dc.w    $5E78
        dc.w    $11B8
        dc.w    $1F00
        dc.w    $3F00
        dc.w    $5EC7
        dc.w    $7E0F
        dc.w    $A4D8
        dc.w    $9D17
        dc.w    $C3E0
        dc.w    $C41F
        dc.w    $DAE8
        dc.w    $E1F0
        dc.w    $E137
        dc.w    $E238
        dc.w    $E1F8
        dc.w    $E2F8
        dc.w    $E3F8
        dc.w    $E4F8
        dc.w    $11F7
        dc.w    $04CC
        dc.w    $0501
        dc.w    $01C0
        dc.w    $0240
        dc.w    $9F38
        dc.w    $66C7



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
		dc.b		" abcdefghij      THE FUCKING BEST REPLICANTS ST AMIGOS PRESENTS:- EMLYN HUGUES FOOTBALL - BROKEN BY THE REPLICANTS     ONLY A FEW FUCKINGS TO NOCKTANAL THE CANADIANS DICKHEAD, OVERWANKERS DAY AFTER DAY YEAR AFTER YEAR YOU ARE LAMEST AND LAMEST JUST SOME GREETINGS TO OUR BEST FRIENDS: MCA, AUTOMATION, "
		dc.b		"HOTLINE, TCB, TEX, DEREK MD...  CREDITS FOR THIS SCREEN                    CODING -VICKERS-                    AMIGAFONT RIPPER -VANTAGE- FROM ST CONNEXION                    BIG REPLICANTS LOGO BY -PULSAR- FROM NEXT                    MUSIX -MAD MAX- FROM -T-          END OF SCROLL       "
fin_texte_scrolling:
		even

	.phrase
fichier_coso_depacked:
		.incbin		"C:\\Jaguar\\COSO\\fichiers mus\\COSO\\SEVGATES.MUS"
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
		.dphrase
DEBUT_BSS:
YM_registres_Coso:			ds.b		14

	.phrase
frequence_Video_Clock:					ds.l				1
frequence_Video_Clock_divisee :			.ds.l				1

YM_nombre_de_frames_totales:			ds.l				1
YM_frequence_replay:					ds.l				1
	.phrase

YM_pointeur_origine_ymdata:		ds.l		1
YM_frequence_predivise:			ds.l		1


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
			.phrase
zone_scroller:
						ds.b		320*2*32*2
;ecran1:				ds.b		640*256				; 8 bitplanes

	.dphrase
motif_raster__data:
	ds.b		2*4*198*128

FIN_RAM:
