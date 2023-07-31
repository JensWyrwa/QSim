! --------------------------------------------------------------------------- !
!  QSim - Programm zur Simulation der Wasserqualität                          !
!                                                                             !
!  Copyright (C) 2022                                                         !
!  Bundesanstalt für Gewässerkunde                                            !
!  Koblenz (Deutschland)                                                      !
!  http://www.bafg.de                                                         !
!                                                                             !
!  Dieses Programm ist freie Software. Sie können es unter den Bedingungen    !
!  der GNU General Public License, Version 3, wie von der Free Software       !
!  Foundation veröffentlicht, weitergeben und/oder modifizieren.              !
!                                                                             !
!  Die Veröffentlichung dieses Programms erfolgt in der Hoffnung, dass es     !
!  Ihnen von Nutzen sein wird, aber ohne irgendeine Garantie, sogar ohne die  !
!  implizite Garantie der Makrtreife oder der Verwendbarkeit für einen        !
!  bestimmten Zweck.                                                          !
!                                                                             !
!  Details finden Sie in der GNU General Public License.                      !
!  Sie sollten ein Exemplar der GNU General Public License zusammen mit       !
!  diesem Programm erhalten haben.                                            !
!  Falls nicht, siehe http://www.gnu.org/licenses/.                           !
!                                                                             !
!  Programmiert von                                                           !
!  1979 bis 2018   Volker Kirchesch                                           !
!  seit 2011       Jens Wyrwa, Wyrwa@bafg.de                                  !
! --------------------------------------------------------------------------- !

subroutine ausgeben()
   use modell
   implicit none
   call mpi_barrier (mpi_komm_welt, ierr)
   call gather_benthic()
   call gather_ueber()
   !! Aufruf immer nach stofftransport() daher ist gather_planktkon() immer schon gemacht
   if (meinrang == 0) then ! nur auf Prozessor 0 bearbeiten
      select case (hydro_trieb)
         case(1) ! casu-transinfo
            call ausgeben_casu()
         case(2) ! Untrim² netCDF
            call ausgeben_untrim(rechenzeit)
         case(3) ! SCHISM
            !!!### call ausgeben_schism(rechenzeit)
            case default
            print*,'hydro_trieb = ',hydro_trieb
            call qerror('ausgeben: Hydraulischer Antrieb unbekannt')
      end select
   endif ! nur Prozessor 0
   call mpi_barrier (mpi_komm_welt, ierr)
   return
end subroutine ausgeben
!----+-----+----+-----+----+-----+----+-----+----
!> Suboutine tagesmittelwert() macht tagesmittelwerte
!! \n\n
subroutine tagesmittelwert()
   use modell
   implicit none
   integer j,n, ion, open_error, system_error, errcode
   real tagesanteil, null
   character(len = longname) :: dateiname, dateiname2, systemaufruf, zahl
   character(50) tm,tt,tj
   null = 0.0
   !if(.true.) then ! heute mittelwertausgabe
   if ((monat == 7) .and. (tag >= 5).and.(tag <= 25)) then ! heute mittelwertausgabe
      if (uhrzeit_stunde < uhrzeit_stunde_vorher) then ! Tageswechsel
         write(zahl,*)rechenzeit
         write(tj,'(I4.4)')jahr
         write(tm,'(I2.2)')monat
         write(tt,'(I2.2)')tag
         zahl = adjustl(zahl)
         tj = adjustl(tj)
         tm = adjustl(tm)
         tt = adjustl(tt)
         ion = 105
         write(dateiname,'(8A)',iostat = errcode)trim(modellverzeichnis),'mittelwert',trim(tj),'_',trim(tm),'_',trim(tt),'.vtk'
         if (errcode /= 0)call qerror('tagesmittelwert writing filename mittelwert failed')
         print*,'Ausgabe Mittelwert auf: ',trim(dateiname)
         write(systemaufruf,'(2A)',iostat = errcode)'rm -rf ',trim(dateiname)
         if (errcode /= 0)call qerror('tagesmittelwert writing system call rm -rf dateiname mittelwert failed')
         call system(trim(systemaufruf),system_error)
         if (system_error /= 0) then
            print*,'rm -rf mittelwert_*** failed.'
         endif ! system_error.ne.0
         open ( unit = ion , file = dateiname, status = 'new', action = 'write', iostat = open_error )
         if (open_error /= 0) then
            write(fehler,*)'open_error mittelwert_vtk open_error = ',open_error
            call qerror(fehler)
         endif ! open_error.ne.0
         if (knotenanzahl2D /= number_benthic_points) then
            write(fehler,*)'3D noch nicht vorgesehen hier'
            call qerror(fehler)
         endif !
         if (number_plankt_point /= knotenanzahl2D) then
            write(fehler,*)'number_plankt_point und knotenanzahl2D passen nicht zusammen ???'
            call qerror(fehler)
         endif !
         !write(ion,*)'huhu ausgabe'
         write(ion,'(A)')'# vtk DataFile Version 3.0'
         write(ion,'(A)')'Simlation tiqusim'
         write(ion,'(A)')'ASCII'
         !write(ion,'(A)')'DATASET POLYDATA'
         write(ion,'(A)')'DATASET UNSTRUCTURED_GRID'
         !
         write(ion,'(A)')' '
         write(ion,'(A,2x,I12,2x,A)')'POINTS ',knotenanzahl2D, ' float'
         do n = 1,knotenanzahl2D
            write(ion,'(f17.5,2x,f17.5,2x,f8.3)') knoten_x(n), knoten_y(n), knoten_z(n)
         enddo ! alle Knoten
         if (element_vorhanden) then
            ! Elemente ausgeben
            write(ion,'(A)')' '
            write(ion,'(A,2x,I12,2x,I12)')'CELLS ', n_elemente, summ_ne
            do n = 1,n_elemente ! alle Elemente
               if (cornernumber(n) == 3) then
                  write(ion,'(4(I8,2x))') cornernumber(n),elementnodes(n,1),elementnodes(n,2),elementnodes(n,3)
               endif
               if (cornernumber(n) == 4) then
                  write(ion,'(5(I8,2x))') cornernumber(n),elementnodes(n,1),elementnodes(n,2),elementnodes(n,3),elementnodes(n,4)
               endif
            enddo ! alle Elemente
            write(ion,'(A)')' '
            write(ion,'(A,2x,I12)')'CELL_TYPES ', n_elemente
            do n = 1,n_elemente ! alle Elemente
               if (cornernumber(n) == 3)write(ion,'(A)') '5'
               if (cornernumber(n) == 4)write(ion,'(A)') '9'
            enddo ! alle Elemente
         else ! keine file.elements vorhanden
            ! Punkte als vtk-vertices
            write(ion,'(A)')' '
            write(ion,'(A,2x,I12,2x,I12)')'CELLS ', knotenanzahl2D, 2*knotenanzahl2D
            do n = 1,knotenanzahl2D
               write(ion,'(A,2x,I8)')'1', n-1
            enddo ! alle Knoten
            write(ion,'(A)')' '
            write(ion,'(A,2x,I12)')'CELL_TYPES ', knotenanzahl2D
            do n = 1,knotenanzahl2D
               write(ion,'(A)')'1'
            enddo ! alle Knoten
         endif !! element_vorhanden
         write(ion,'(A)')' '
         write(ion,'(A,2x,I12)')'POINT_DATA ', knotenanzahl2D
         write(ion,'(A)')'SCALARS Gelaendehoehe float 1'
         write(ion,'(A)')'LOOKUP_TABLE default'
         do n = 1,knotenanzahl2D
            write(ion,'(f27.6)') knoten_z(n)
         enddo ! alle Knoten
         write(ion,'(A)')'SCALARS T_wass_mittel float 1'
         write(ion,'(A)')'LOOKUP_TABLE default'
         do n = 1,knotenanzahl2D
            write(ion,'(f27.6)') transfer_quantity_p(68+(n-1)*number_trans_quant)
         enddo ! alle Knoten
         write(ion,'(A)')'SCALARS T_sed_mittel float 1'
         write(ion,'(A)')'LOOKUP_TABLE default'
         do n = 1,knotenanzahl2D
            write(ion,'(f27.6)') transfer_quantity_p(69+(n-1)*number_trans_quant)
         enddo ! alle Knoten
         write(ion,'(A)')'SCALARS mittel_tief float 1'
         write(ion,'(A)')'LOOKUP_TABLE default'
         do n = 1,knotenanzahl2D
            if (transfer_quantity_p(71+(n-1)*number_trans_quant) > 0.0) then
               write(ion,'(f27.6)') transfer_quantity_p(70+(n-1)*number_trans_quant)  &
                                   / transfer_quantity_p(71+(n-1)*number_trans_quant)    ! tagesmittelwert Wassertiefe
            else
               write(ion,'(f27.6)') null
            endif
         enddo ! alle Knoten
         write(ion,'(A)')'SCALARS Bedeckungsdauer float 1'
         write(ion,'(A)')'LOOKUP_TABLE default'
         do n = 1,knotenanzahl2D
            write(ion,'(f27.6)') transfer_quantity_p(71+(n-1)*number_trans_quant)
         enddo ! alle Knoten
         do n = 1,knotenanzahl2D
            transfer_quantity_p(68+(n-1)*number_trans_quant) = 0.0
            transfer_quantity_p(69+(n-1)*number_trans_quant) = 0.0
            transfer_quantity_p(70+(n-1)*number_trans_quant) = 0.0
            transfer_quantity_p(71+(n-1)*number_trans_quant) = 0.0
         enddo ! alle Knoten wieder null setzen
         close(ion)
      endif ! Tageswechsel
      tagesanteil = real(deltat)/real(86400)
      do n = 1,knotenanzahl2D  !!!!!!!!!!!  mittelwerte aufsummieren
         transfer_quantity_p(68+(n-1)*number_trans_quant) = transfer_quantity_p(68+(n-1)*number_trans_quant)  &
                                                          + (planktonic_variable_p(1+(n-1)*number_plankt_vari)  * tagesanteil) ! Wasser-Temperatur Rückgabewert
         transfer_quantity_p(69+(n-1)*number_trans_quant) = transfer_quantity_p(69+(n-1)*number_trans_quant)  &
                                                          + (benthic_distribution_p(1+(n-1)*number_benth_distr) * tagesanteil) ! Temperatur des Sediments - Rückgabewert
         if (rb_hydraul(2+(n-1)*number_rb_hydraul) > 0.02) then ! tief(n)
            transfer_quantity_p(70+(n-1)*number_trans_quant) = transfer_quantity_p(70+(n-1)*number_trans_quant)  &
                                                             + (rb_hydraul(2+(n-1)*number_rb_hydraul) * tagesanteil) ! TagesSumme Tiefe wenn bedeckt
            transfer_quantity_p(71+(n-1)*number_trans_quant) = transfer_quantity_p(71+(n-1)*number_trans_quant)  &
                                                             + (tagesanteil) ! Bedeckungsdauer (Tageanteil)
         endif
      enddo ! alle Knoten
   endif ! heute mittelwertberechnung
   uhrzeit_stunde_vorher = uhrzeit_stunde
   return
end subroutine tagesmittelwert
!----+-----+----
!> Suboutine ausgabekonzentrationen() ließt aus der Datei
!! <a href="./exp/ausgabekonzentrationen.txt" target="_blank">ausgabekonzentrationen.txt</a>
!! welche variablen ausgegeben werden sollen.\n
!! als Beispiel-Datei, der entnehmbar ist, welche Variablen ausgegeben werden könnnen, schreibt ausgabekonzentrationen()
!! die Datei ausgabekonzentrationen_beispiel.txt \n
!! Die angekreuzten, gewählten Variablen werden sowohl bei den Ganglinien als auch bei den ausgabezeitpunkten verwendet.
!!\n\n
!! aus Datei ausgabe.f95 ; zurück zu \ref lnk_modellerstellung
subroutine ausgabekonzentrationen()
   use modell
   implicit none
   integer :: ion, ibei, open_error, io_error, alloc_status, iscan, j, n, sysa
   character (len = 200) :: dateiname, text
   logical :: found
   character(300) systemaufruf
   !>integer :: k_ausgabe
   !>integer , allocatable , dimension (:) :: ausgabe_konz
   output_plankt(:) = .false.
   output_plankt_vert(:) = .false.
   output_benth_distr(:) = .false.
   output_trans_val(:) = .false.
   output_trans_quant(:) = .false.
   output_trans_quant_vert(:) = .false.
   write(dateiname,'(2A)')trim(modellverzeichnis),'ausgabekonzentrationen.txt'
   ion = 103
   open ( unit = ion , file = dateiname, status = 'old', action = 'read ', iostat = open_error )
   if (open_error /= 0) then
      print*,'keine ausgabekonzentrationen, open_error = ',open_error
      close (ion)
      return
   else
      print*,'ausgabekonzentrationen.txt geoeffnet ...'
   endif ! open_error.ne.0
   do while ( zeile(ion)) !!  read all lines and understand
      if ((ctext(1:1) == 'x') .or. (ctext(1:1) == 'X')) then ! line marked ?
         found = .false.
         !print*,trim(ctext)
         do j = 1,number_plankt_vari ! all depth averaged planktic con.
            write(text,'(A18)')trim(planktonic_variable_name(j))
            iscan = index(trim(ctext),trim(text))
            if (iscan > 0) then ! found
               print*,meinrang,iscan,' output for planktic concentration j = ',j,' parameter: ',trim(text)
               !print*,trim(ctext)
               output_plankt(j) = .true.
               found = .true.
            endif !! in string ctext
         enddo ! done all planktic con.
         do j = 1,number_plankt_vari_vert ! all vertically distributed planktonic variables
            write(text,'(A18)')trim(plankt_vari_vert_name(j))
            iscan = index(trim(ctext),trim(text))
            if (iscan > 0) then ! found
               if (meinrang == 0)print*,'output only for level 1; plankt_vari_vert j = ',j,' parameter: ',trim(text)
               !print*,trim(ctext)
               output_plankt_vert(j) = .true.
               found = .true.
            endif !! in string ctext
         enddo ! done all plankt_vari_vert
         do j = 1,number_benth_distr ! all benthic distributions
            write(text,'(A)')ADJUSTL(trim(benth_distr_name(j)))
            iscan = index(trim(ctext),trim(text))
            if (iscan > 0) then ! found
               if (meinrang == 0)print*,'output for benthic distribution j = ',j,' parameter: ',trim(text)
               !print*,trim(ctext)
               output_benth_distr(j) = .true.
               found = .true.
            endif !! in string ctext
            ! ausgabe_bentver(j)=.true. ! überbrückt: ### alle
            ! ausgabe_bentver(j)=.false. ! überbrückt: ### keine
         enddo ! done all all benthic distributions
         do j = 1,number_trans_val  ! alle globalen Übergabe Werte
            write(text,'(A)')ADJUSTL(trim(trans_val_name(j)))
            iscan = index(trim(ctext),trim(text))
            if (iscan > 0) then ! found
               print*,'ausgabe globaler uebergabe wert j = ',j,' parameter: ',trim(text)
               !print*,trim(ctext)
               output_trans_val(j) = .true.
               found = .true.
            endif !! in string ctext
         enddo !
         do j = 1,number_trans_quant ! all exchange con.
            write(text,'(A)')ADJUSTL(trim(trans_quant_name(j)))
            iscan = index(trim(ctext),trim(text))
            if (iscan > 0) then ! found
               if (meinrang == 0)print*,'output for exchange concentration j = ',j,' parameter: ',trim(text)
               !print*,trim(ctext)
               output_trans_quant(j) = .true.
               found = .true.
            endif !! in string ctext
            ! output_trans_quant(j)=.true. ! überbrückt: ### alle
            ! output_trans_quant(j)=.false. ! überbrückt: ### keine
         enddo ! done all exchange con.
         do j = 1,number_trans_quant_vert  ! all vertically distributed transfer quantities
            write(text,'(A)')ADJUSTL(trim(trans_quant_vert_name(j)))
            iscan = index(trim(ctext),trim(text))
            if (iscan > 0) then ! found
               if (meinrang == 0)print*,'output only for level 1; trans_quant_vert j = ',j,' parameter: ',trim(text)
               !print*,trim(ctext)
               output_trans_quant_vert(j) = .true.
               found = .true.
            endif !! in string ctext
         enddo ! done all vertically distributed transfer quantities
         if ( .not. found) then
            print*,'no parameter found for choice:'
            !print*,trim(ctext)
         endif ! not found
      endif ! marked line
   enddo ! no further line
   close (ion)
   if (nur_alter) then ! allways write age concentrations in age simulation
      output_plankt(71) = .true. ! Tracer
      output_plankt(73) = .true. ! age_decay
      output_plankt(74) = .true. ! age_arith
      output_plankt(75) = .true. ! age_growth
   endif ! nuralter
   
   n_pl = 0
   do j = 1,number_plankt_vari
      if (output_plankt(j))n_pl = n_pl+1
   enddo
   do j = 1,number_plankt_vari_vert
      if (output_plankt_vert(j))n_pl = n_pl+1
   enddo
   n_bn = 0
   do j = 1,number_benth_distr
      if (output_benth_distr(j))n_bn = n_bn+1
   enddo
   n_ue = 0
   do j = 1,number_trans_val
      if (output_trans_val(j))n_ue = n_ue+1
   enddo
   do j = 1,number_trans_quant
      if (output_trans_quant(j))n_ue = n_ue+1
   enddo
   do j = 1,number_trans_quant_vert
      if (output_trans_quant_vert(j))n_ue = n_ue+1
   enddo
   print*,'ausgabekonzentrationen n_pl,n_bn,n_ue = ',n_pl,n_bn,n_ue
   !     writing output variable list moved to SUBROUTINE eingabe()
   !text='ausgabekonzentrationen_beispiel.txt'
   !dateiname=trim(adjustl(modellverzeichnis))//trim(adjustl(text))
   !systemaufruf='cp '//trim(adjustl(codesource))//'/'//trim(adjustl(text))//' '//trim(dateiname)
   !call system(systemaufruf,sysa)
   !if(sysa.ne.0) Print*,'### kopieren von ',trim(adjustl(text)),' ausgabekonzentrationen_beispiel.txt fehlgeschlagen ###'
   return
end subroutine ausgabekonzentrationen
!----+-----+----
!> suboutine ausgabekonzentrationen_beispiel writes file ausgabekonzentrationen_beispiel.txt to inform about available output variables
!! \n\n
subroutine ausgabekonzentrationen_beispiel()
   use modell
   implicit none
   integer :: j,open_error
   character (len = 300) :: dateiname
   write(dateiname,'(2A)')trim(modellverzeichnis),'ausgabekonzentrationen_beispiel.txt'
   open ( unit = 104 , file = dateiname, status = 'replace', action = 'write ', iostat = open_error )
   if (open_error /= 0) then
      print*,'ausgabekonzentrationen_beispiel.txt open_error = ',open_error
      close (104)
      return
   else
      print*,'ausgabekonzentrationen_beispiel.txt opened for write ...'
   endif ! open_error.ne.0
   write(104,'(A)')"# depth averaged, planctonic, transported concentrations"
   do j = 1,number_plankt_vari ! all depth averaged planktic con.
      write(104,'(A1,7x,I4,2x,A18)')"0",j,trim(planktonic_variable_name(j))
   enddo ! done all planktic con.
   write(104,'(A)')"# depth resolving, planctonic, transported concentrations"
   do j = 1,number_plankt_vari_vert ! all vertically distributed planktonic variables
      write(104,'(A1,7x,I4,2x,A18)')"0",j,trim(plankt_vari_vert_name(j))
   enddo ! done all plankt_vari_vert
   write(104,'(A)')"# bentic distributions"
   do j = 1,number_benth_distr ! all benthic distributions
      write(104,'(A1,7x,I4,2x,A18)')"0",j,trim(benth_distr_name(j))
   enddo ! done all benthic distributions
   write(104,'(A)')"# global transfer variables"
   do j = 1,number_trans_val  ! alle globalen Übergabe Werte
      write(104,'(A1,7x,I4,2x,A18)')"0",j,trim(trans_val_name(j))
   enddo
   write(104,'(A)')"# depth averaged transfer variables"
   do j = 1,number_trans_quant ! all exchange con.
      write(104,'(A1,7x,I4,2x,A18)')"0",j,trim(trans_quant_name(j))
   enddo
   write(104,'(A)')"# depth resolving transfer variables"
   do j = 1,number_trans_quant_vert  ! all vertically distributed transfer quantities
      write(104,'(A1,7x,I4,2x,A18)')"0",j,trim(trans_quant_vert_name(j))
   enddo
   close (104)
   return
end subroutine ausgabekonzentrationen_beispiel


!> Read file `ausgabezeitpunkte.txt` 
!!
!! Datetime defined in `ausgabezeitpunkte.txt` are stored in variable 
!! `ausgabe_zeitpunkt`.
subroutine ausgabezeitpunkte()
   use modell
   use module_datetime
   implicit none
   
   integer        :: n, u_out, open_error, io_error, nba
   integer        :: day, month, year, hour, second
   character(200) :: filename
   type(datetime), dimension(:), allocatable :: datetime_output
   
   
   filename = trim(modellverzeichnis) // 'ausgabezeitpunkte.txt'
   u_out = 103
   open(newunit = u_out , file = filename, status = 'old', action = 'read ', iostat = open_error)
   if (open_error /= 0) call qerror ("could not open " // trim(filename))
   
   
   ! determine number of output times
   n_output = 0
   do while (zeile(u_out))
      ! commented lines ('#') are skipped
      if (ctext(1:1) /= '#') then
         n_output = n_output + 1
         read(ctext,*, iostat = io_error) day, month, year, hour, minute, second
         if (io_error /= 0) call qerror("error while reading " // trim(filename))
      endif 
   enddo 
   
   allocate(ausgabe_zeitpunkt(n_output))
   allocate(ausgabe_bahnlinie(n_output))
   allocate(datetime_output(n_output))

   
   ! --- read dates for output ---
   rewind(u_out)
   n = 0
   do while (zeile(u_out))
      if (ctext(1:1) /= '#') then ! keine kommentarzeile
         n = n + 1
         read(ctext,*) day, month, year, hour, minute, second
         
         datetime_output(n) = datetime(year, month, day, hour, minute, tz = tz_qsim)
         ausgabe_zeitpunkt(n) = datetime_output(n) % seconds_since_epoch()
         
         ! check for trajectory output
         read(ctext,*, iostat = io_error) day, month, year, hour, minute, second, nba
         if (io_error == 0) then
            ausgabe_bahnlinie(n) = nba
         else
            ausgabe_bahnlinie(n) = 0
         endif 
      endif 
   enddo 
   close (u_out)
   
   
   ! --- print summary to console ---
   print* 
   print "(a)", repeat("-", 80)
   print "(a)", "output settings"
   print "(a)", repeat("-", 80)
   
   print "(a,i0)",  "n_output = ", n_output
   print "(3a,i0)", "first output = ", datetime_output(1) % date_string(),        " | ",  ausgabe_zeitpunkt(1) 
   print "(3a,i0)", "last output =  ", datetime_output(n_output) % date_string(), " | ",  ausgabe_zeitpunkt(n_output) 
   
   if (any(ausgabe_zeitpunkt < startzeitpunkt .or. ausgabe_zeitpunkt > endzeitpunkt)) then
      print*
      print "(a)", "note:"
      print "(a)", "  some output dates are outside of the simulated timeperiod and will "
      print "(a)", "  not be included in the model results."
   
   endif
   
end subroutine ausgabezeitpunkte

!> true if output required now
subroutine ausgeben_parallel()
   use modell
   implicit none
   
   integer :: alloc_status
   
   call MPI_Bcast(n_output, 1, MPI_INT, 0, mpi_komm_welt, ierr)
   if (ierr /= 0) call qerror("Error while mpi_bcast of variable `n_output`.")
      
   if (meinrang /= 0) then
      allocate(ausgabe_zeitpunkt(n_output), stat = alloc_status)
      allocate(ausgabe_bahnlinie(n_output), stat = alloc_status)
   endif

   call MPI_Bcast(ausgabe_zeitpunkt, n_output, MPI_INTEGER8, 0, mpi_komm_welt, ierr)
   if (ierr /= 0) call qerror("Error while mpi_bcast of variable `ausgabe_zeitpunkt`.")
   
   call MPI_Bcast(ausgabe_bahnlinie,n_output,MPI_INT,0,mpi_komm_welt,ierr)
   if (ierr /= 0) call qerror("Error while mpi_bcast of variable `ausgabe_bahnlinie`.")
   
end subroutine ausgeben_parallel


!> true if output required now
logical function jetzt_ausgeben()
   use modell
   implicit none
   integer :: n , diff
   jetzt_ausgeben = .false.
   bali = .false.
   !if(hydro_trieb.eq. 3)then
   !   jetzt_ausgeben=.FALSE.
   !   if(meinrang.eq. 0)print*,'SCHISM preliminary: no output for all timesteps'
   !   return
   !endif ! SCHISM
   
   do n = 1,n_output,1
      diff = ausgabe_zeitpunkt(n)-rechenzeit
      if ( (diff >= (-1*(deltat/2))) .and. (diff < (deltat/2)) ) then
         jetzt_ausgeben = .TRUE.
         if (ausgabe_bahnlinie(n) /= 0) bali = .TRUE.
      endif !
      !print*,'ausgeben? ', rechenzeit, ausgabe_punkt(n), deltat, (rechenzeit-ausgabe_punkt(n))
      !if(((rechenzeit-ausgabe_punkt(n)).lt.deltat).and.((rechenzeit-ausgabe_punkt(n)).ge.0))then
      !if(((rechenzeit-ausgabe_punkt(1)).lt.deltat).and.((rechenzeit-ausgabe_punkt(1)).ge.0))then
      !   print*,'jetzt jede Stunde ausgeben'
      !   ausgabe_punkt(1)=ausgabe_punkt(1)+3600
      !   jetzt_ausgeben=.TRUE.
      !endif !
   enddo
   !if(.not.jetzt_ausgeben)jetzt_ausgeben=(zeitschrittanzahl.eq.izeit) !! Ausgabe am Ende
   if (jetzt_ausgeben)print*,'jetzt_ausgeben ,meinrang',meinrang
   return
end function jetzt_ausgeben
!----+-----+----
!> Initialisierung der transportierten Übergabe-Konzentrationen.
!! \n\n
subroutine ini_aus(nk)
   use modell
   implicit none
   integer nk,k,n,as,j
   if (meinrang == 0) then ! nur auf Prozessor 0 bearbeiten
      knotenanzahl_ausgabe = nk
      anzahl_auskonz = 1
      allocate (AusgabeKonzentrationsName(anzahl_auskonz), stat = as )
      if (as /= 0) then
         write(fehler,*)' Rueckgabewert   von   allocate AusgabeKonzentrationsName :', as
         call qerror(fehler)
      endif
      AusgabeKonzentrationsName( 1) = "            BACmua"
      !!!!!!!!! ausgabe_konzentration allokieren und initialisieren
      allocate (ausgabe_konzentration(anzahl_auskonz,knotenanzahl_ausgabe), stat = as )
      if (as /= 0) then
         write(fehler,*)' Rueckgabewert   von   allocate transfer_quantity :', as
         call qerror(fehler)
      endif
      do k = 1,knotenanzahl_ausgabe ! alle knoten
         do j = 1,anzahl_auskonz ! initialisierung aller konzentrationen zunächt auf Null
            ausgabe_konzentration(j,k) = 0.0
         enddo
      enddo
   endif !! nur prozessor 0
end subroutine ini_aus
!----+-----+----
!> ELCIRC .grd Format ausgabe momentan Sept15 Überstaudauern für Elbestabil
!! \n\n
subroutine aus_grd()
   use modell
   implicit none
   integer :: ion, open_error, io_error, n
   character (len = 200) :: dateiname
   if ( .not. uedau_flag) return !! Überstaudauern nur ausgeben wenn parameter in module_modell.f95 gesetzt
   if (uedau_flag) call qerror(" aus_grd() Überstaudauer nicht mehr implementiert")
   if (meinrang == 0) then ! nur auf Prozessor 0 bearbeiten
      write(dateiname,'(2A)')trim(modellverzeichnis),'uedau0.grd'
      ion = 107
      open ( unit = ion , file = dateiname, status = 'unknown', action = 'write ', iostat = open_error )
      if (open_error /= 0) then
         print*,'uedau0.grd, open_error = ',open_error
         close (ion)
         return
      endif ! open_error.ne.0
      
      write(ion,'(A)') 'Grid written by QSim3D'
      write(ion,'(I9,2x,I9)')n_elemente, knotenanzahl2D
      
      do n = 1,knotenanzahl2D
         ! write(ion,'(I9,2x,f11.4,2x,f11.4,2x,f11.4)')n, knoten_x(n), knoten_y(n), p(n) !! Wasserspiegellage
         write(ion,'(I9,2x,f11.4,2x,f11.4,2x,f11.4)')n, knoten_x(n), knoten_y(n),   &
                                                     benthic_distribution(44+(n-1)*number_benth_distr)  !! Überstaudauer
      enddo ! alle Knoten
      
      do n = 1,n_elemente ! alle Elemente
         if (cornernumber(n) == 3) then
            write(ion,'(5(I8,2x))') &
                                n, cornernumber(n),elementnodes(n,1),elementnodes(n,2),elementnodes(n,3)
         endif
         if (cornernumber(n) == 4) then
            write(ion,'(6(I8,2x))') &
                                n, cornernumber(n),elementnodes(n,1),elementnodes(n,2),elementnodes(n,3),elementnodes(n,4)
         endif
      enddo ! alle Elemente
      
      close (ion)
      print*,'Überstaudauer 0-15 cm (44) ausgegeben auf: uedau0.grd'
      !!!!!!!!!
      write(dateiname,'(2A)')trim(modellverzeichnis),'uedau15.grd'
      ion = 107
      open ( unit = ion , file = dateiname, status = 'unknown', action = 'write ', iostat = open_error )
      if (open_error /= 0) then
         print*,'uedau15.grd, open_error = ',open_error
         close (ion)
         return
      endif ! open_error.ne.0
      
      write(ion,'(A)') 'Grid written by QSim3D'
      write(ion,'(I9,2x,I9)')n_elemente, knotenanzahl2D
      
      do n = 1,knotenanzahl2D
         ! write(ion,'(I9,2x,f11.4,2x,f11.4,2x,f11.4)')n, knoten_x(n), knoten_y(n), p(n) !! Wasserspiegellage
         write(ion,'(I9,2x,f11.4,2x,f11.4,2x,f11.4)')n, knoten_x(n), knoten_y(n),   &
                                                     benthic_distribution(45+(n-1)*number_benth_distr)  !! Überstaudauer
      enddo ! alle Knoten
      
      do n = 1,n_elemente ! alle Elemente
         if (cornernumber(n) == 3) then
            write(ion,'(5(I8,2x))') &
                                n, cornernumber(n),elementnodes(n,1),elementnodes(n,2),elementnodes(n,3)
         endif
         if (cornernumber(n) == 4) then
            write(ion,'(6(I8,2x))') &
                                n, cornernumber(n),elementnodes(n,1),elementnodes(n,2),elementnodes(n,3),elementnodes(n,4)
         endif
      enddo ! alle Elemente
      
      close (ion)
      print*,'Überstaudauer 15-25 cm (45) ausgegeben auf: uedau15.grd'
      !!!!!!!!!
      write(dateiname,'(2A)')trim(modellverzeichnis),'uedau25.grd'
      ion = 107
      open ( unit = ion , file = dateiname, status = 'unknown', action = 'write ', iostat = open_error )
      if (open_error /= 0) then
         print*,'uedau25.grd, open_error = ',open_error
         close (ion)
         return
      endif ! open_error.ne.0
      
      write(ion,'(A)') 'Grid written by QSim3D'
      write(ion,'(I9,2x,I9)')n_elemente, knotenanzahl2D
      
      do n = 1,knotenanzahl2D
         ! write(ion,'(I9,2x,f11.4,2x,f11.4,2x,f11.4)')n, knoten_x(n), knoten_y(n), p(n) !! Wasserspiegellage
         write(ion,'(I9,2x,f11.4,2x,f11.4,2x,f11.4)')n, knoten_x(n), knoten_y(n),   &
                                                     benthic_distribution(46+(n-1)*number_benth_distr)  !! Überstaudauer
      enddo ! alle Knoten
      
      do n = 1,n_elemente ! alle Elemente
         if (cornernumber(n) == 3) then
            write(ion,'(5(I8,2x))') n, cornernumber(n),elementnodes(n,1),elementnodes(n,2),elementnodes(n,3)
         endif
         if (cornernumber(n) == 4) then
            write(ion,'(6(I8,2x))') n, cornernumber(n),elementnodes(n,1),elementnodes(n,2),elementnodes(n,3),elementnodes(n,4)
         endif
      enddo ! alle Elemente
      
      close (ion)
      print*,'Überstaudauer 25-35 cm (46) ausgegeben auf: uedau25.grd'
      
      
      write(dateiname,'(2A)')trim(modellverzeichnis),'uedau35.grd'
      ion = 107
      open ( unit = ion , file = dateiname, status = 'unknown', action = 'write ', iostat = open_error )
      if (open_error /= 0) then
         print*,'uedau35.grd, open_error = ',open_error
         close (ion)
         return
      endif ! open_error.ne.0
      
      write(ion,'(A)') 'Grid written by QSim3D'
      write(ion,'(I9,2x,I9)')n_elemente, knotenanzahl2D
      
      do n = 1,knotenanzahl2D
         ! write(ion,'(I9,2x,f11.4,2x,f11.4,2x,f11.4)')n, knoten_x(n), knoten_y(n), p(n) !! Wasserspiegellage
         write(ion,'(I9,2x,f11.4,2x,f11.4,2x,f11.4)')n, knoten_x(n), knoten_y(n),   &
                                                     benthic_distribution(47+(n-1)*number_benth_distr)  !! Überstaudauer
      enddo ! alle Knoten
      
      do n = 1,n_elemente ! alle Elemente
         if (cornernumber(n) == 3) then
            write(ion,'(5(I8,2x))') &
                                n, cornernumber(n),elementnodes(n,1),elementnodes(n,2),elementnodes(n,3)
         endif
         if (cornernumber(n) == 4) then
            write(ion,'(6(I8,2x))') &
                                n, cornernumber(n),elementnodes(n,1),elementnodes(n,2),elementnodes(n,3),elementnodes(n,4)
         endif
      enddo ! alle Elemente
      
      close (ion)
      print*,'Überstaudauer 35-undendl. cm (47) ausgegeben auf: uedau35.grd'
   endif !! nur prozessor 0
   return
end subroutine aus_grd
!----+-----+----
!> Kontrollausgabe des Netzes\n
!! \n\n
!! aus: ausgabe.f95 ; zurück: \ref lnk_ergebnisausgabe
subroutine show_mesh()
   use modell
   implicit none
   character(len = longname) :: dateiname, systemaufruf
   integer n, ion, open_error, nel, ner, alloc_status,errcode
   real :: dummy
   !if(hydro_trieb.eq. 3) return ! SCHISM not available yet
   if (meinrang == 0) then ! nur auf Prozessor 0 bearbeiten
      !-------------------------------------------------------------------------------------------- nodes
      write(dateiname,'(4A)',iostat = errcode)trim(modellverzeichnis),'mesh_node.vtk'
      if (errcode /= 0)call qerror('show_mesh writing filename mesh_node failed')
      write(systemaufruf,'(2A)',iostat = errcode)'rm -rf ',trim(dateiname)
      if (errcode /= 0)call qerror('show_mesh writing system call rm -rf dateiname mesh_node failed')
      call system(systemaufruf)
      ion = 106
      open ( unit = ion , file = dateiname, status = 'new', action = 'write ', iostat = open_error )
      if (open_error /= 0) then
         write(fehler,*)'open_error mesh_node.vtk'
         call qerror(fehler)
      endif ! open_error.ne.0
      call mesh_output(ion)
      print*,'show_mesh:mesh_node.vtk done'
      close (ion)
      !-------------------------------------------------------------------------------------------- edges=sides
      if (hydro_trieb == 3) then ! schism
         write(dateiname,'(4A)',iostat = errcode)trim(modellverzeichnis),'mesh_midedge.vtk'
         if (errcode /= 0)call qerror('show_mesh writing filename mesh_midedge failed')
         write(systemaufruf,'(2A)',iostat = errcode)'rm -rf ',trim(dateiname)
         if (errcode /= 0)call qerror('show_mesh writing system call rm -rf dateiname mesh_midedge failed')
         call system(systemaufruf)
         open ( unit = ion , file = dateiname, status = 'new', action = 'write', iostat = open_error )
         if (open_error /= 0) then
            write(fehler,*)'open_error mesh_midedge.vtk'
            call qerror(fehler)
         endif ! open_error.ne.0
         print*,
         write(ion,'(A)')'# vtk DataFile Version 3.0'
         write(ion,'(A)')'Simlation QSim3D SCHISM'
         write(ion,'(A)')'ASCII'
         write(ion,'(A)')'DATASET UNSTRUCTURED_GRID'
         write(ion,'(A)')' '
         write(ion,'(A,2x,I12,2x,A)')'POINTS ',kantenanzahl, ' float'
         do n = 1,kantenanzahl
            write(ion,'(f17.5,2x,f17.5,2x,f8.3)') 0.5*(knoten_x(top_node(n))+knoten_x(bottom_node(n)))  &
                                                 , 0.5*(knoten_y(top_node(n))+knoten_y(bottom_node(n))), 0.0
         enddo ! alle kanten
         write(ion,'(A)')' '
         write(ion,'(A,2x,I12,2x,I12)')'CELLS ', kantenanzahl, kantenanzahl*2
         do n = 1,kantenanzahl
            write(ion,'(A,2x,I12)')'1',n-1
         enddo ! alle kanten
         write(ion,'(A)')' ' ! vtk-vertex
         write(ion,'(A,2x,I12)')'CELL_TYPES ', kantenanzahl
         do n = 1,kantenanzahl
            write(ion,'(A)')'1'
         enddo ! alle kanten
         write(ion,'(A)')' '
         write(ion,'(A,2x,I12)')'POINT_DATA ', kantenanzahl
         write(ion,'(A)')'SCALARS length float 1'
         write(ion,'(A)')'LOOKUP_TABLE default'
         do n = 1,kantenanzahl
            write(ion,'(f27.6)') cell_bound_length(n) ! real(n) ! ed_area(n)
         enddo ! alle kanten
         ! write(ion,'(A)')'SCALARS volume_flux float 1'
         ! write(ion,'(A)')'LOOKUP_TABLE default'
         ! do n=1,kantenanzahl
         !    write(ion,'(f27.6)') ed_flux(n)
         ! enddo ! alle kanten
         dummy = 0.0
         write(ion,'(A)')'VECTORS normal float'
         do n = 1,kantenanzahl
            write(ion,'(6x, f11.6, 2x, f11.6, 2x, f11.6)') edge_normal_x(n),edge_normal_y(n),dummy
         enddo ! all edges/sides
         close (ion)
         print*,'show_mesh:mesh_midedge.vtk schism done',kantenanzahl
         
         write(dateiname,'(4A)',iostat = errcode)trim(modellverzeichnis),'mesh_side.vtk'
         if (errcode /= 0)call qerror('show_mesh writing filename mesh_side failed')
         write(systemaufruf,'(2A)',iostat = errcode)'rm -rf ',trim(dateiname)
         if (errcode /= 0)call qerror('show_mesh writing system call rm -rf dateiname mesh_side failed')
         call system(systemaufruf)
         open ( unit = ion , file = dateiname, status = 'new', action = 'write', iostat = open_error )
         if (open_error /= 0) then
            write(fehler,*)'open_error mesh_side.vtk'
            call qerror(fehler)
         endif ! open_error.ne.0
         print*,
         write(ion,'(A)')'# vtk DataFile Version 3.0'
         write(ion,'(A)')'Simlation QSim3D SCHISM'
         write(ion,'(A)')'ASCII'
         write(ion,'(A)')'DATASET UNSTRUCTURED_GRID'
         write(ion,'(A)')' '
         write(ion,'(A,2x,I12,2x,A)')'POINTS ',knotenanzahl2D, ' float'
         do n = 1,knotenanzahl2D
            write(ion,'(f17.5,2x,f17.5,2x,f8.3)') knoten_x(n), knoten_y(n), knoten_z(n)
         enddo ! alle kanten
         write(ion,'(A)')' '
         write(ion,'(A,2x,I12,2x,I12)')'CELLS ', kantenanzahl, kantenanzahl*3
         do n = 1,kantenanzahl
            write(ion,'(A,2x,I12,2x,I12)')'2',top_node(n)-1,bottom_node(n)-1
         enddo ! alle kanten
         write(ion,'(A)')' ' ! vtk-vertex
         write(ion,'(A,2x,I12)')'CELL_TYPES ', kantenanzahl
         do n = 1,kantenanzahl
            write(ion,'(A)')'3'
         enddo ! alle kanten
         dummy = 123.4
         write(ion,'(A)')' '
         write(ion,'(A,2x,I12)')'POINT_DATA ', knotenanzahl2D
         write(ion,'(A)')'SCALARS dummy float 1'
         write(ion,'(A)')'LOOKUP_TABLE default'
         do n = 1,knotenanzahl2D
            write(ion,'(f27.6)') dummy ! real(n) ! ed_area(n)
         enddo ! alle kanten
         ! write(ion,'(A)')'SCALARS volume_flux float 1'
         ! write(ion,'(A)')'LOOKUP_TABLE default'
         ! do n=1,kantenanzahl
         !    write(ion,'(f27.6)') ed_flux(n)
         ! enddo ! alle kanten
         close (ion)
         print*,'show_mesh:mesh_side.vtk schism done',kantenanzahl
      endif ! schism
      !-------------------------------------------------------------------------------------------- faces=elements
      kanten_vorhanden = .false. !! geht schief bei casu ????
      !! if(kanten_vorhanden)then
      if ((hydro_trieb == 2) .or. (kanten_vorhanden)) then ! untrim
         write(dateiname,'(4A)',iostat = errcode)trim(modellverzeichnis),'mesh_element.vtk'
         if (errcode /= 0)call qerror('show_mesh writing filename mesh_element failed')
         write(systemaufruf,'(2A)',iostat = errcode)'rm -rf ',trim(dateiname)
         if (errcode /= 0)call qerror('show_mesh writing system call rm -rf dateiname mesh_element failed')
         call system(systemaufruf)
         ion = 106
         open ( unit = ion , file = dateiname, status = 'unknown', action = 'write ', iostat = open_error )
         if (open_error /= 0) then
            write(fehler,*)'open_error mesh_element.vtk'
            call qerror(fehler)
         endif ! open_error.ne.0
         write(ion,'(A)')'# vtk DataFile Version 3.0'
         write(ion,'(A)')'mesh_element '
         write(ion,'(A)')'ASCII'
         write(ion,'(A)')'DATASET UNSTRUCTURED_GRID'
         write(ion,'(A)')' '
         write(ion,'(A,2x,I12,2x,A)')'POINTS ',n_elemente+knotenanzahl2D, ' float'
         dummy = 0.0
         do n = 1,n_elemente
            write(ion,'(f17.5,2x,f17.5,2x,f8.3)') element_x(n), element_y(n), dummy
         enddo ! all elements/faces
         do n = 1,knotenanzahl2D
            write(ion,'(f17.5,2x,f17.5,2x,f8.3)') knoten_x(n), knoten_y(n), knoten_z(n)
         enddo ! alle Knoten
         write(ion,'(A)')' '
         write(ion,'(A,2x,I12,2x,I12)')'CELLS ', kantenanzahl, 3*kantenanzahl
         do n = 1,kantenanzahl
            nel = left_element(n)
            ner = right_element(n)
            if (boundary_number(n) > 0 ) then
               ner = n_elemente+top_node(n)
               nel = n_elemente+bottom_node(n)
            endif
            write(ion,'(A,2x,I8,2x,I8)')'2', nel-1, ner-1
         enddo ! alle Knoten
         write(ion,'(A)')' '
         write(ion,'(A,2x,I12)')'CELL_TYPES ', kantenanzahl
         do n = 1,kantenanzahl
            write(ion,'(A)')'3'
         enddo ! alle kanten
         write(ion,'(A)')' '
         write(ion,'(A,2x,I12)')'POINT_DATA ', n_elemente+knotenanzahl2D
         write(ion,'(A)')'SCALARS boundary float 1'
         write(ion,'(A)')'LOOKUP_TABLE default'
         do n = 1,n_elemente
            write(ion,'(f27.6)') real(element_rand(n))
         enddo
         do n = 1,knotenanzahl2D
            write(ion,'(f27.6)') real(knoten_rand(n))
         enddo ! alle Knoten
         print*,'show_mesh: mesh_element.vtk done'
         close (ion)
      endif! edges
   endif ! nur Prozessor 0
   return
end subroutine show_mesh
!----+-----+----+-----+----+-----+----+-----+----+-----+----
subroutine mesh_output(ion)
   use modell
   implicit none
   character(len = longname) :: dateiname
   integer ion,n,igr3
   integer io_error
   !print*,'mesh_output: starting'
   !----------------------------------------------------------------- .vtk
   write(ion,'(A)')'# vtk DataFile Version 3.0'
   write(ion,'(A)')'Simlation QSim3D'
   write(ion,'(A)')'ASCII'
   !write(ion,'(A)')'DATASET POLYDATA'
   write(ion,'(A)')'DATASET UNSTRUCTURED_GRID'
   !
   write(ion,'(A)')' '
   write(ion,'(A,2x,I12,2x,A)')'POINTS ',knotenanzahl2D, ' float'
   do n = 1,knotenanzahl2D
      write(ion,'(f17.5,2x,f17.5,2x,f8.3)') knoten_x(n), knoten_y(n), knoten_z(n)
   enddo ! alle Knoten
   if (element_vorhanden) then
      ! Elemente ausgeben (Knotennummern in paraview wieder von 0 beginnend !!
      write(ion,'(A)')' '
      write(ion,'(A,2x,I12,2x,I12)')'CELLS ', n_elemente, summ_ne
      do n = 1,n_elemente ! alle Elemente
         if (cornernumber(n) == 3) then
            write(ion,'(4(I8,2x))') cornernumber(n),elementnodes(n,1)-1,elementnodes(n,2)-1,elementnodes(n,3)-1
         endif
         if (cornernumber(n) == 4) then
            write(ion,'(5(I8,2x))') cornernumber(n),elementnodes(n,1)-1,elementnodes(n,2)-1,elementnodes(n,3)-1,elementnodes(n,4)-1
         endif
      enddo ! alle Elemente
      write(ion,'(A)')' '
      write(ion,'(A,2x,I12)')'CELL_TYPES ', n_elemente
      do n = 1,n_elemente ! alle Elemente
         if (cornernumber(n) == 3)write(ion,'(A)') '5'
         if (cornernumber(n) == 4)write(ion,'(A)') '9'
      enddo ! alle Elemente
   else ! keine file.elements vorhanden
      ! Punkte als vtk-vertices
      write(ion,'(A)')' '
      write(ion,'(A,2x,I12,2x,I12)')'CELLS ', knotenanzahl2D, 2*knotenanzahl2D
      do n = 1,knotenanzahl2D
         write(ion,'(A,2x,I8)')'1', n-1
      enddo ! alle Knoten
      write(ion,'(A)')' '
      write(ion,'(A,2x,I12)')'CELL_TYPES ', knotenanzahl2D
      do n = 1,knotenanzahl2D
         write(ion,'(A)')'1'
      enddo ! alle Knoten
   endif !! element_vorhanden
   write(ion,'(A)')' '
   write(ion,'(A,2x,I12)')'POINT_DATA ', knotenanzahl2D
   write(ion,'(A)')'SCALARS Gelaendehoehe float 1'
   write(ion,'(A)')'LOOKUP_TABLE default'
   do n = 1,knotenanzahl2D
      write(ion,'(f27.6)') knoten_z(n)
   enddo ! alle Knoten
   !write(ion,'(A)')'SCALARS zonen_nummer float 1'
   !write(ion,'(A)')'LOOKUP_TABLE default'
   !do n=1,knotenanzahl2D
   !   if(knoten_zone(n).eq. 0)call qerror('mesh_output: knoten_zone must not be zero')
   !   write(ion,'(f27.6)') real( zonen_nummer(knoten_zone(n)) )
   !enddo ! alle Knoten
   write(ion,'(A)')'SCALARS knoten_zone float 1'
   write(ion,'(A)')'LOOKUP_TABLE default'
   do n = 1,knotenanzahl2D
      write(ion,'(f27.6)') real( knoten_zone(n) )
   enddo ! alle Knoten
   write(ion,'(A)')'SCALARS knoten_rand float 1'
   write(ion,'(A)')'LOOKUP_TABLE default'
   do n = 1,knotenanzahl2D
      write(ion,'(f27.6)') real(knoten_rand(n))
   enddo ! alle Knoten
   !close (ion) !channel number is handeled by subroutine show_mesh
   
   !----------------------------------------------------------------- .gr3
   if (meinrang /= 0)call qerror("mesh_output may only be called from process 0") ! nur auf Prozessor 0 bearbeiten
   
   write(dateiname,'(2A)')trim(modellverzeichnis),'mesh.gr3'
   igr3 = 107
   open ( unit = igr3 , file = dateiname, status = 'unknown', action = 'write ', iostat = io_error )
   if (io_error /= 0) then
      print*,'mesh.gr3, io_error = ',io_error
      close (igr3)
      return
   endif ! io_error.ne.0
   
   write(igr3,'(A,2x,A)') 'Grid written by QSim3D',modellverzeichnis
   write(igr3,*)n_elemente, knotenanzahl2D
   
   do n = 1,knotenanzahl2D
      ! write(igr3,'(I9,2x,f11.4,2x,f11.4,2x,f11.4)')n, knoten_x(n), knoten_y(n), p(n) !! Wasserspiegellage
      write(igr3,*)n, knoten_x(n), knoten_y(n), knoten_z(n)
   enddo ! alle Knoten
   
   do n = 1,n_elemente ! alle Elemente
      if (cornernumber(n) == 3) then
         write(igr3,*) &
                      n, cornernumber(n),elementnodes(n,1),elementnodes(n,2),elementnodes(n,3)
      endif
      if (cornernumber(n) == 4) then
         write(igr3,*) &
                      n, cornernumber(n),elementnodes(n,1),elementnodes(n,2),elementnodes(n,3),elementnodes(n,4)
      endif
   enddo ! alle Elemente
   
   close (igr3)
   !print*,'written mesh.gr3'
   !print*,'mesh_output: finished'
   return
end subroutine mesh_output
!----+-----+----+-----+----+-----+----+-----+----+-----+----
!> raus ist true, wenn in diesem Zeitschritt das Geschwindigkeitsfeld ausgegeben werden soll \n\n
!! \n\n
!      SUBROUTINE ausgabezeitpunkt(raus)
!      use modell
!      implicit none
!      logical :: raus
!      raus=.TRUE.
!      return
!      END SUBROUTINE ausgabezeitpunkt
