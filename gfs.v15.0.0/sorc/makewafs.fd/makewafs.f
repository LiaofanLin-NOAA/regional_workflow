      PROGRAM MAKEWAFS
C$$$  MAIN PROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C MAIN PROGRAM: MAKEWAFS
C   PRGMMR: VUONG            ORG: NP11        DATE: 2005-05-03
C
C ABSTRACT: PROGRAMS READS GRIB FILE WITH 1 DEGREE (GRID 3) RECORDS,
C           UNPACKS THEM, AND MAKES 8 GRIB GRID 37-44 RECORDS FROM
C           EACH 1 DEGREE RECORDS.  THEN, ADD A TOC FLAG FIELD SEPARATOR
C           BLOCK AND WMO HEADER IN FRONT OF EACH GRIB FIELD, AND WRITES
C           THEM OUT TO A NEW FILE.  THE OUTPUT FILE IS IN THE FORMAT
C           REQUIRED FOR TOC'S FTP INPUT SERVICE, WHICH CAN BE USED TO
C           DISSEMINATE THE GRIB BULLETINS.
C
C PROGRAM HISTORY LOG:
C 1994-07-11  R.E.JONES
C 1994-09-13  R.E.JONES   ADD WXFA03V TO CONVERT TRO PRES TO TRO HGT
C                         AND MWSL PRES TO MWSL HGT
C 1995-01-26  R.E.JONES   ADD MORE ERROR MESSAGES
C 1995-01-27  R.E.JONES   LET MODEL NUMBER BE TRUE, WAS SET TO 77.
C 1995-03-21  R.E.JONES   CORRECT ERROR MESSAGE ABOUT MISSING
C                         BULLETINS.
C 1998-05-22  VUONG       REMOVED CALLS TO W3LOG AND W3FS11 AND REPLACED
C                         CALLS TO W3FQ02 WITH CALLS TO W3UTCDAT. SUBROUTINE
C                         MAKWMO NOW OBTAINS DAY AND HOUR FROM IDAWIP
C 1999-08-18  VUONG       CONVERTED TO RUN ON THE IBM SP
C 2005-05-03  VUONG       ADD A TOC FLAG FIELD SEPARATOR BLOCK AND WMO HEADER
C                         IN FRONT OF EACH GRIB FIELD
C 2010-07-13  VUONG       INCREASED SIZE OF ARRAY MXSIZE
C 2012-10-22  VUONG       CHANGED VARIABLE ENVVAR TO CHARACTER*6
C
C USAGE:
C   INPUT FILES:
C      5       - STANDARD FORTRAN INPUT FILE.
C     11       - ONE DEGREE GRIB TYPE 3 FILE 
C     31       - GRIB INDEX FILE FOR FILE 11
C
C   OUTPUT FILES:  
C      6       - STANDARD FORTRAN PRINT FILE
C     51       - GRIB GRID TYPE 37-44 RECORDS MADE FROM GRIB
C                GRID 3 ONE DEGREE RECORDS.
C     53       - GRIB GRID TYPE 37 RECORDS MADE FOR TUNISIA
C                WMO GRIB GRIB "I".
C
C   SUBPROGRAMS CALLED: (LIST ALL CALLED FROM ANYWHERE IN CODES)
C     UNIQUE:    - HEXCHAR GETGB WXFA03V
C     LIBRARY:
C       W3LIB    - W3TAGB IW3JDN IW3PDS W3FP11 W3UTCDAT
C                  W3FI68 W3FI71 W3FI72 W3FI73 W3FI74 W3FI75
C                  W3FI76 W3AI19 W3FI63 XMOVEX XSTORE
C     
C   EXIT STATES:
C     COND =   0 - SUCCESSFUL RUN
C             18 - ERROR READING CONTROL CARD FILE
C             19 - ERROR READING CONTROL CARD FILE
C             20 - W3FI62 ERROR MAKING QUEUE DISCRIPTER
C             30 - BULLITENS ARE MISSING
C           1100 - UNEXPECTED EOF READING INPUT FILE
C
C REMARKS: LIST CAVEATS, OTHER HELPFUL HINTS OR INFORMATION
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 90
C
C$$$
C
      PARAMETER (IPTS=65160,II=360,JJ=181)
      PARAMETER (LUGI=31,LUGB=11,LUGO=51)
      PARAMETER (MXSIZE=100000,MXSIZ2=MXSIZE*2)
      PARAMETER (LENHEAD=21,LUGO53=53)
C
      REAL            C(MXSIZE)
C     REAL            TEMP(MXSIZE)
      REAL            HEIGHT(MXSIZE)
      REAL            CC(II,JJ)
      REAL            HI(4000)
C
      INTEGER         D(20)
      INTEGER         IFLD(4000)
      INTEGER         IBDSFL(12)
      INTEGER         IBMAP(4000)
      INTEGER         IBUF(4000)
      INTEGER         ID3744(25)
      INTEGER         IGDS1(100)
      INTEGER         IGRIB(16500)
      INTEGER         IPDS(4)
      INTEGER         JPDS(4)
      INTEGER         JGDS(100)
      INTEGER         MPDS(25)
      INTEGER         IPDS37(4)
      INTEGER         ITIME(8)
      INTEGER         KGDS(100)
      INTEGER         KPDS(25)
      INTEGER         MAPNUM(20)
      INTEGER         NBITS(20)
      INTEGER         NBUL
      INTEGER         PUNUM
C
      CHARACTER * 6   BULHED(20)
      CHARACTER * 17  DESC
      CHARACTER * 3   EOML
      CHARACTER * 1   GRIB(MXSIZ2)
      CHARACTER * 2   HEXPDS(28)
      CHARACTER * 44  INFILE
      CHARACTER * 1   KBUF(16000)
      CHARACTER * 2   NGBFLG
      CHARACTER * 1   PDS(28)
      CHARACTER * 1   PDSL(28)
      CHARACTER * 1   PDS3744(28)
      CHARACTER * 132 TITLE
      CHARACTER * 1   WMOHDR(21)
      CHARACTER * 6   ENVVAR
      CHARACTER * 80  FILEB, FILEI,FILEO
      CHARACTER * 1   CSEP(80)
      CHARACTER * 4   KWBX
C
      LOGICAL         IW3PDS
      LOGICAL         KBMS(MXSIZE)
      LOGICAL         MWSLHGT
      LOGICAL         MWSLTMP
      LOGICAL         TROPHGT
C
      SAVE
C
      EQUIVALENCE     (C(1),CC(1,1))
      EQUIVALENCE     (IBUF(1),KBUF(1))
      EQUIVALENCE     (GRIB(1),IGRIB(1))
      EQUIVALENCE     (IPDS(1),PDS(1))
      EQUIVALENCE     (JPDS(1),PDSL(1),IGRIB(2))
      EQUIVALENCE     (PDS3744(1),IPDS37(1))
C
      DATA  IBDSFL/ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0/
      DATA  IBMAP / 4000 * 1 /
C
      CALL W3TAGB('MAKEWAFS',2004,0267,0267,'NP11')
C
C     GET PARM FIELD WITH UP TO 100 CHARACTERS
C
      KWBX  = 'KWBC'
      IRET   = 0
      IOPT   = 2
      INSIZE = 19
      NBUL   = 0
      NUMID  = 0
      NSTOP  = 0
      KERR   = 0
      NGBSUM = 0
C
C     READ GRIB DATA AND INDEX FILE NAMES FROM THE FORTnn
C     ENVIRONMENT VARIABLES, AND OPEN THE FILES.
C
      ENVVAR='FORT  '
      WRITE(ENVVAR(5:6),FMT='(I2)') LUGB
      CALL GETENV(ENVVAR,FILEB)
      WRITE(ENVVAR(5:6),FMT='(i2)') LUGI
      CALL GETENV(ENVVAR,FILEI)

      CALL BAOPENR(LUGB,FILEB,IRET1)
      IF ( IRET1  .NE. 0 ) THEN
        WRITE(6,FMT='(" ERROR OPENING GRIB FILE: ",A80)') FILEB
        WRITE(6,FMT='(" BAOPENR ERROR = ",I5)') IRET1
        STOP 10
      ENDIF

      CALL BAOPENR(LUGI,FILEI,IRET2)
      IF ( IRET2  .NE. 0 ) THEN
        WRITE(6,FMT='(" ERROR OPENING GRIB FILE: ",A80)') FILEB
        WRITE(6,FMT='(" BAOPENR ERROR = ",I5)') IRET2
        STOP 10
      ENDIF
C
C     READ OUTPUT GRIB BULLETIN FILE NAME FROM FORTnn
C     ENVIRONMENT VARIABLE, AND OPEN FILE.
C
      WRITE(ENVVAR(5:6),FMT='(I2)') LUGO
      CALL GETENV(ENVVAR,FILEO)
      CALL BAOPENW(LUGO,FILEO,IRET3)
      IF ( IRET3  .NE. 0 ) THEN
        WRITE(6,FMT='(" ERROR OPENING OUTPUT GRIB FILE: ",A80)') FILEO
        WRITE(6,FMT='(" BAOPENW ERROR = ",I5)') IRET3
        STOP 20
      ENDIF
C
C     OPEN OUTPUT FILE GRIB GRID TYPE 37 RECORDS MADE FOR TUNISIA
C
      WRITE(ENVVAR(5:6),FMT='(I2)') LUGO53
      CALL GETENV(ENVVAR,FILEO)
      CALL BAOPENW(LUGO53,FILEO,IRET4)
      IF ( IRET4  .NE. 0 ) THEN
        WRITE(6,FMT='(" ERROR OPENING OUTPUT GRIB FILE: ",A80)') FILEO
        WRITE(6,FMT='(" BAOPENW ERROR = ",I5)') IRET4
        STOP 20
      ENDIF
C
      CALL W3UTCDAT (ITIME)
C     PRINT *,'ITIME = ',ITIME
C
      DO 700 NUMFIL = 1,25
C
      NREC = 0
      DO 699 IREAD = 1,1000
C
C       CRAY CAN NOT USE Z2.2 HEX FORMAT FOR CHARACTER DATA, USE
C       A2 FORMAT AND THEN CALL HEXCHAR TO DO EQIUVALENT WORK
C
        READ (*,66,END=800) (HEXPDS(J),J=1,12),
     &        (HEXPDS(J),J=17,20), PUNUM, NGBFLG, DESC
 66     FORMAT(3(2X,4A2),3X,4A2,6X,I3,1X,A2,1X,A17)
        NREC = NREC + 1
        LLERR = 0
        DO J = 1,12
          CALL HEXCHAR(HEXPDS(J),PDS(J),LERR)
          IF (LERR.NE.0) LLERR = LLERR + 1
        END DO
        DO J = 17,20
          CALL HEXCHAR(HEXPDS(J),PDS(J),LERR)
          IF (LERR.NE.0) LLERR = LLERR + 1
        END DO
C
C       CHARACTERS ON CONTROL CARD NOT 0-9, A-F, OR a-f
C
        IF (MOVA2I(PDS(1)) .EQ. 255) GO TO 700
        IF (LLERR.NE.0) PRINT *,'HEXCHAR ERROR = ',LLERR
        WRITE (6,FMT='(/,''**************************************'',
     &      ''************************************************'')')
        PRINT *,'START NEW MAP RECORD NO. = ',NREC
        WRITE (6,FMT='('' INPUT PDS, PUNUM, NGBFLG'',
     &        '' & DESC...DESIRED GRIB MAPS LISTED ON FOLLOWING '',
     &        ''LINES...'',/,4X,3(2X,4A2),3X,4A2,6X,I3,1X,A2,
     &        1X,A17)') (HEXPDS(J),J=1,12),
     &        (HEXPDS(J),J=17,20), PUNUM, NGBFLG, DESC
      NUMID = NUMID + 1
      NGB   = 0
      DO 130 J = 1,20
        READ (*,END=710,FMT='(4X,I3,2X,I2,2X,A6,1X,I3,24X,A3)')
     &          MAPNUM(J),NBITS(J), BULHED(J), D(J), EOML
        WRITE (6,FMT='(4X,I3,2X,I2,2X,A6,1X,I3,24X,A3)')
     &           MAPNUM(J),NBITS(J), BULHED(J), D(J), EOML
                NGB = J
                IF (EOML .EQ. 'EOM') THEN
                  GO TO 200
                END IF
  130 CONTINUE

  200 CONTINUE
C
      NGBSUM  = NGBSUM + NGB
      MWSLHGT = .FALSE.
      MWSLTMP = .FALSE.
      TROPHGT = .FALSE.
      JREW   = 0
      MPDS   = -1
      MPDS(5) = MOVA2I(PDS(9))
      MPDS(6) = MOVA2I(PDS(10))
      MPDS(7) = MOVA2I(PDS(11)) * 256 + MOVA2I(PDS(12))
C
C     TEST FOR TROP HGT, GET TROP PRES INSTEAD
C
      IF (MPDS(5).EQ.7.AND.MPDS(6).EQ.7.AND.
     &  MPDS(7).EQ.0) THEN
        MPDS(5) = 1
        TROPHGT = .TRUE.
      END IF
C
C     TEST FOR MWSL HGT, GET MWSL PRES INSTEAD
C
      IF (MPDS(5).EQ.7.AND.MPDS(6).EQ.6.AND.
     &  MPDS(7).EQ.0) THEN
        MPDS(5) = 1
        MWSLHGT = .TRUE.
      END IF
C
C     TEST FOR MWSL TEMP, GET MWSL PRES INSTEAD
C
C     IF (MPDS(5).EQ.11.AND.MPDS(6).EQ.6.AND.
C    &  MPDS(7).EQ.0) THEN
C       MPDS(5) = 1
C       MWSLTMP = .TRUE.
C     END IF
C
C     READ I DEGREE GRIB FILE USING INDEX FILE
C
      CALL GETGB(LUGB,LUGI,MXSIZE,JREW,MPDS,JGDS,
     &     KBYTES,KREW,KPDS,KGDS,KBMS,C,IRET)
      CALL GETGBP(LUGB,LUGI,MXSIZ2,KREW-1,MPDS,JGDS,
     &      KBYTES,KREW,KPDS,KGDS,GRIB,IRET)
      PRINT *,'RECORD NO. OF GRIB RECORD IN INPUT FILE = ',KREW
      IF (IRET.NE.0) THEN
        PRINT *,'GETGB ERROR = ',IRET
        GO TO 699
      END IF
C
C     COMPARE RECORD (GRIB) TO CONTROL CARD (PDS), THEY SHOULD MATCH
C
      IF (TROPHGT) THEN
        PDSL(9) = CHAR(7)
      END IF
      IF (MWSLHGT) THEN
        PDSL(9) = CHAR(7)
      END IF
C     IF (MWSLTMP) THEN
C       PDSL(9) = CHAR(11)
C     END IF
C
      KEY = 2
      IF (.NOT.IW3PDS(PDSL,PDS,KEY)) THEN
        PRINT 2900, IREAD, JPDS,IPDS
2900   FORMAT ( 1X,I4,' (PDS) IN RECORD DOES NOT MATCH (PDS) IN ',
     & 'CONTROL CARD ',/,4(1X,Z16), /,4(1X,Z16))
       GO TO 699
      END IF
C
      PRINT 2, (JPDS(J),J=1,4)
 2    FORMAT (' PDS = ',4(Z16,1X))
c
      CALL W3FP11 (IGRIB,IGRIB(2),TITLE,IER)
      IF (IER.NE.0) PRINT *,'W3FP11 ERROR = ',IER
C     PRINT *,' '
      PRINT *,TITLE(1:86)
      PRINT *,' '
      IF (IRET.NE.0) GO TO 699
C
      IF (TROPHGT.OR.MWSLHGT) THEN
C     IF (TROPHGT.OR.MWSLHGT.OR.MWSLTMP) THEN
C
C       CALL WXFA03V TO CONVERT TROP PRES TO TROP HGT, OR MWSL
C       PRES TO MWSL HGT, OR MWSL PRES TO MWSL TMP
C
C       RESCALE DATA TO MILLBARS
C
        DO J = 1,65160
          C(J) = C(J) * 0.01
        END DO
C
        CALL WXFA03V(C,HEIGHT,65160)
C       CALL WXFA03V(C,HEIGHT,TEMP,65160)
C
        IF (TROPHGT.OR.MWSLHGT) THEN
          PRINT *,'WXFA03V USED TO CONVERT PRES INTO HEIGHT'
          DO J = 1,65160
            C(J) = HEIGHT(J)
          END DO
C       ELSE
C         DO J = 1,65160
C           C(J) = TEMP(J)
C         END DO
        END IF
C
      END IF
C
C     CONVERT UNPACKED GRIB 1 DEG. RECORDS INTO 8 37-44
C     MAKE
C
      DO 690 I = 1,NGB
        CALL W3FT26 (MAPNUM(I),C,HI,IGPTS,NSTOP)
C
C       PRINT *,'CHECK POINT AFTER WFSTRP, IGPTS = ',IGPTS
C
C       caLL W3FI69 TO UNPACK PDS INTO 25 WORD INTEGER ARRAY
C
        CALL W3FI69(PDSL,ID3744)
C
C       CHANGE MODEL NUMBER AND GRID TYPE$
C       LET MODEL NUMBER BE TRUE, WILL BE 81 FOR 00HR$
C       WILL BE 77 FOR 06 TO 72 HRS.   95-01-27$
C       WILL THIS CHANGE CAUSE USERS TO SCREAM??$
C       UNCOMMENT THE NEXT CARD TO SET MODEL NUMBER TO 77$
C
C       ID3744(4) = 77
        ID3744(5) = MAPNUM(I)
C
C       TEST RELATIVE HUMIDITY FOR GT THAN 100.0 AND LT 0.0
C       IF SO, RESET TO 0.0 AND 100.0
C
        IF (ID3744(8).EQ.52) THEN
          DO J = 1,IGPTS
            IF (HI(J).GT.100.0) HI(J) = 100.0
            IF (HI(J).LT.0.0)   HI(J) =   0.0
          END DO
        END IF
C
C       IF D VALUE EQUAL ZERO, USE D VALUE IN 1 DEGREE INPUT RECORDS,
C       ELSE USE THE D VALUE
C
        IF (D(I).NE.0) THEN
          ID3744(25) = D(I)
        END IF
C
C       RESET SCALING TO ZERO
C
        IF (TROPHGT.OR.MWSLHGT) THEN
          ID3744(25) = 0
        END IF
C       IF (MWSLTMP) THEN
C         ID3744(25) = 1
C       END IF
C
C       PRINT *,'W3FT69 = ',ID3744
C       PRINT *,'CHECK POINT AFTER W3FI69'
C
        IBITL  = NBITS(I)
        ITYPE  = 0
        IGRID  = MAPNUM(I)
        IPFLAG = 0
        IGFLAG = 0
        IBFLAG = 0
        ICOMP  = 0
        IBLEN  = IGPTS
        JERR   = 0
C
C     GRIB AWIPS grid 37-44
C
C         PRINT *,'CHECK POINT BEFORE W3FI72'
          CALL W3FI72(ITYPE,HI,IFLD,IBITL,
     &                IPFLAG,ID3744,PDS3744,
     &                IGFLAG,IGRID,IGDS1,ICOMP,
     &                IBFLAG,IBMAP,IBLEN,
     &                IBDSFL,
     &                NPTS,KBUF,ITOT,JERR)
C         PRINT *,'CHECK POINT AFTER W3FI72'
          IF (JERR.NE.0) PRINT *,' W3FI72 ERROR = ',JERR
C         PRINT *,'(IGDS1 ARRAY) = '
C         PRINT *, IGDS1
          PRINT *,'NPTS, ITOT = ',NPTS,ITOT
          PRINT 2, (IPDS37(J),J=1,4)
C         PRINT 2, (PDS3744(J),J=1,LENPDS)
C
C       MAKE FLAG FIELD SEPARATOR BLOCK
C
          CALL MKFLDSEP(CSEP,IOPT,INSIZE,ITOT+LENHEAD,LENOUT)
C
C         MAKE WMO HEADER
C
          CALL MAKWMO (BULHED(I),KPDS(10),KPDS(11),KWBX,WMOHDR)
C
C     WRITE OUT SEPARATOR BLOCK, ABBREVIATED WMO HEADING,
C
C     THESE NEXT 3 LINES CAN BE REMOVED WHEN TUNISIA FTP TESTING
C     IS COMPETED...IF  'WAFS GRID I'  WRITE TO 53.
C
          IF (WMOHDR(3).EQ.'I') THEN
            PRINT *,'GRIB GRID 37 FOR TUNISIA WMOHDR(3)= ', WMOHDR(3)
            CALL WRYTE(LUGO53,LENOUT,CSEP)
            CALL WRYTE(LUGO53,LENHEAD,WMOHDR)
            CALL WRYTE(LUGO53,ITOT,KBUF)
          END IF
C
          CALL WRYTE(LUGO,LENOUT,CSEP)
          CALL WRYTE(LUGO,LENHEAD,WMOHDR)
          CALL WRYTE(LUGO,ITOT,KBUF)
          NBUL    = NBUL + 1
  690 CONTINUE
C
  699 CONTINUE
  700 CONTINUE
C
C$    ERROR MESSAGES
C
  710 CONTINUE
      WRITE (6,FMT='(''  ?*?*? CHECK DATA CARDS... READ IN '',
     & ''GRIB PDS AND WAS EXPECTING GRIB MAP CARDS TO FOLLOW.'',/,
     & ''           MAKE SURE NGBFLG = ZZ OR SUPPLY '',
     & ''SOME GRIB MAP DEFINITIONS!'')')
      CALL W3TAGE('MAKEWAFS')
      STOP 18
C--------------------------------------------------------------
C
C*     CLOSING SECTION
c
  800 CONTINUE
        IF (NBUL .EQ. 0 .AND. NUMFLD .EQ. 0) THEN
          WRITE (6,FMT='('' SOMETHING WRONG WITH DATA CARDS...'',
     &           ''NOTHING WAS PROCESSED'')')
          CALL W3TAGE('MAKEWAFS')
          STOP 19
        ELSE
          CALL BACLOSE (LUGB,IRET)
          CALL BACLOSE (LUGI,IRET)
          CALL BACLOSE (LUGO,IRET)
          CALL BACLOSE (LUGO53,IRET)
          WRITE (6,FMT='(//,'' ******** RECAP OF THIS EXECUTION '',
     &    ''********'',/,5X,''READ  '',I6,'' INDIVIDUAL IDS'',
     &    /,5X,''WROTE '',I6,'' BULLETINS OUT FOR TRANSMISSION'',
     &    //)') NUMID, NBUL
C
C         TEST TO SEE IF ANY BULLETINS MISSING
C
          MBUL = 0
          MBUL = NGBSUM - NBUL
          IF (MBUL.NE.0) THEN
            PRINT *,'BULLETINS MISSING = ',MBUL
            CALL W3TAGE('MAKEWAFS')
            STOP 30
          END IF
C
          CALL W3TAGE('MAKEWAFS')
          STOP
        ENDIF
C
 1100 CONTINUE
        PRINT *,'UNEXPECTED EOF ON FILE = ',INFILE
        CALL W3TAGE('MAKEWAFS')
        STOP 1100
      END
C
      SUBROUTINE HEXCHAR(HEX,OUT,IERR)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    HEXCHAR     CORRECT DATA READ WITH A2 FORMAT
C   PRGMMR: R.E.JONES        ORG: W/NMCXX    DATE: YY-MM-DD
C
C ABSTRACT: CRAY DOES NOT ALLOW YOU TO READ CHARACTER DATA WITH
C   Z2.2 FORMAT. DATA IS READ WITH A2 FORMAT AND THIS SUBROUTINE
C   CONVERSTS DATA TO CORRECT VALUES.
C
C PROGRAM HISTORY LOG:
C   94-05-05  R.E.JONES
C
C USAGE:    CALL HEXCHAR(HEX, OUT, IERR)
C   INPUT ARGUMENT LIST:
C     HEX      - CHARACTER*2 HEX INPUT READ WITH A2 FORMAT,
C                BECAUSE Z2.2 FORMAT DOES NOT WORK ON CRAY.
C
C   OUTPUT ARGUMENT LIST:
C     OUT      - A2 INPUT CONVERTED TO BINARY STORED IN ONE
C                CHARACTER.
C     IERR     - 0, IF NO ERRORS
C                1, DATA IS NOT 0-9, A-F, or a-f.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 90
C
C$$$
C
      CHARACTER * 1  OUT
      CHARACTER * 2  HEX
C
      INTEGER        INT
      INTEGER        INT1
      INTEGER        INT2
C
      SAVE
C
      IERR = 0
      INT1 = MOVA2I(HEX(1:1))
      IF (INT1.GE.48.AND.INT1.LE.57) THEN
        INT1 = INT1 - 48
      ELSE IF (INT1.GE.65.AND.INT1.LE.70) THEN
        INT1 = INT1 - 55
      ELSE IF (INT1.GE.97.AND.INT1.LE.102) THEN
        INT1 = INT1 - 87
      ELSE
        IERR = 1
        RETURN
      END IF
C
      INT2 = MOVA2I(HEX(2:2))
      IF (INT2.GE.48.AND.INT2.LE.57) THEN
        INT2 = INT2 - 48
      ELSE IF (INT2.GE.65.AND.INT2.LE.70) THEN
        INT2 = INT2 - 55
      ELSE IF (INT2.GE.97.AND.INT2.LE.102) THEN
        INT2 = INT2 - 87
      ELSE
        IERR = 1
        RETURN
      END IF
      INT = INT1 * 16 + INT2
      OUT = CHAR(INT)
C
      RETURN
      END
C
      SUBROUTINE WXFA03V(PRESS,HEIGHT,N)
C     SUBROUTINE WXFA03V(PRESS,HEIGHT,TEMP,N)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    WXFA03V     COMPUTE STANDARD HEIGHT
C   PRGMMR: KEYSER           ORG: W/NMC22    DATE: 92-06-29
C
C ABSTRACT: COMPUTES THE STANDARD HEIGHT, 
C   GIVEN THE PRESSURE IN MILLIBARS ( > 8.68 MB ).  FOR
C   HEIGHT AND TEMPERATURE THE RESULTS DUPLICATE THE VALUES IN THE
C   U.S. STANDARD ATMOSPHERE (L962), WHICH IS THE ICAO STANDARD
C   ATMOSPHERE TO 54.7487 MB (20 KM) AND THE PROPOSED EXTENSION TO
C   8.68 MB (32 KM).  FOR POTENTIAL TEMPERATURE A VALUE OF  2/7  IS
C   USED FOR  RD/CP.
C
C PROGRAM HISTORY LOG:
C   74-06-01  J. MCDONELL W345     -- ORIGINAL AUTHOR
C   84-06-01  R.E.JONES W342       -- CHANGE TO IBM VS FORTRAN
C   92-06-29  D. A. KEYSER W/NMC22 -- CONVERT TO CRAY CFT77 FORTRAN
C   94-09-13  R.E.JONES   SPECIAL VETORIZED VERSION TO DO JUST HEIGHT
C
C USAGE:    CALL WXFA03V(PRESS,HEIGHT,N)
C USAGE:    CALL WXFA03V(PRESS,HEIGHT,TEMP,N)
C   INPUT ARGUMENT LIST:
C     PRESS    - PRESSURE IN MILLIBARS
C
C   OUTPUT ARGUMENT LIST:
C     HEIGHT   - HEIGHT IN METERS
C     TEMP     - TEMPERATURE ARRAY IN DEGREES KELVIN
C     N        - NUMBER OF POINTS IN ARRAY PRESS
C
C   SUBPROGRAMS CALLED:
C     LIBRARY:
C       CRAY     - ALOG
C
C
C REMARKS: NOT VALID FOR PRESSURES LESS THAN 8.68 MILLIBARS, DECLARE
C   ALL PARAMETERS AS TYPE REAL.
C
C WARNING: SPECIAL VEVECTORIZED VERSION OF W3FA03 TO DO JUST HEIGHT
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 90
C
C$$$
C
      REAL  M0
      REAL  HEIGHT(*)
      REAL  PRESS(*)
C     REAL  TEMP(*)
C
      SAVE
C
      DATA  G/9.80665/,RSTAR/8314.32/,M0/28.9644/,PISO/54.7487/,
     $ ZISO/20000./,SALP/-.0010/,PZERO/1013.25/,T0/288.15/,ALP/.0065/,
     $ PTROP/226.321/,TSTR/216.65/
C
      R     = RSTAR/M0
      ROVG  = R/G
      FKT   = ROVG * TSTR
      AR    = ALP  * ROVG
      PP0   = PZERO**AR
      AR1   = SALP * ROVG
      PP01  = PISO**AR1
C
      DO J = 1,N
      IF (PRESS(J).LT.PISO) THEN
C
C     COMPUTE LAPSE RATE = -.0010 CASES
C
        HEIGHT(J) = ((TSTR/(PP01 * SALP )) * (PP01-(PRESS(J) ** AR1)))
     &              + ZISO
C       TEMP(J)   = TSTR - ((HEIGHT(J) - ZISO) * SALP)
C
      ELSE IF (PRESS(J).GT.PTROP) THEN
C
        HEIGHT(J) = (T0/(PP0 * ALP)) * (PP0 - (PRESS(J) ** AR))
C       TEMP(J)   = T0 - (HEIGHT(J) * ALP)
C
      ELSE
C
C     COMPUTE ISOTHERMAL CASES
C
        HEIGHT(J) = 11000.0 + (FKT * ALOG(PTROP/PRESS(J)))
C       TEMP(J)   = TSTR
C
      END IF
      END DO
C
      RETURN
      END