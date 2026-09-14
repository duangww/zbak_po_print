CLASS lcl_print_buffer DEFINITION.
  PUBLIC SECTION.
    CLASS-DATA gt_ebeln TYPE zcl_mm_r002_service=>tt_ebeln.
    CLASS-METHODS add
      IMPORTING
        it_ebeln TYPE zcl_mm_r002_service=>tt_ebeln.
    CLASS-METHODS consume
      RETURNING
        VALUE(rt_ebeln) TYPE zcl_mm_r002_service=>tt_ebeln.
ENDCLASS.

CLASS lcl_print_buffer IMPLEMENTATION.
  METHOD add.
    APPEND LINES OF it_ebeln TO gt_ebeln.
  ENDMETHOD.

  METHOD consume.
    rt_ebeln = gt_ebeln.
    CLEAR gt_ebeln.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_poprint DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS previewPdf FOR MODIFY
      IMPORTING keys FOR ACTION PoPrint~previewPdf
      RESULT result.

    METHODS confirmPrint FOR MODIFY
      IMPORTING keys FOR ACTION PoPrint~confirmPrint.
ENDCLASS.

CLASS lhc_poprint IMPLEMENTATION.
  METHOD previewPdf.
    DATA: lt_ebeln TYPE zcl_mm_r002_service=>tt_ebeln,
          lv_pdf   TYPE xstring,
          lv_fname TYPE string,
          lv_error TYPE string,
          ls_out   TYPE za_mm_r002_pdf.

    LOOP AT keys INTO DATA(ls_key).
      APPEND ls_key-ebeln TO lt_ebeln.
    ENDLOOP.

    zcl_mm_r002_service=>get_pdf(
      EXPORTING
        it_ebeln  = lt_ebeln
        iv_formid = zcl_mm_r002_service=>gc_form_default
      IMPORTING
        ev_pdf    = lv_pdf
        ev_fname  = lv_fname
        ev_error  = lv_error ).

    ls_out-pdf      = lv_pdf.
    ls_out-mimetype = 'application/pdf'.
    ls_out-filename = CONV #( lv_fname ).
    ls_out-message  = CONV #( lv_error ).

    LOOP AT keys INTO ls_key.
      APPEND VALUE #(
        %tky   = ls_key-%tky
        %param = ls_out ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD confirmPrint.
    DATA lt_ebeln TYPE zcl_mm_r002_service=>tt_ebeln.

    LOOP AT keys INTO DATA(ls_key).
      APPEND ls_key-ebeln TO lt_ebeln.
    ENDLOOP.

    lcl_print_buffer=>add( lt_ebeln ).
  ENDMETHOD.
ENDCLASS.

CLASS lsc_zce_mm_r002 DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS finalize REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save REDEFINITION.
    METHODS cleanup REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.

CLASS lsc_zce_mm_r002 IMPLEMENTATION.
  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD save.
    DATA(lt_ebeln) = lcl_print_buffer=>consume( ).
    IF lt_ebeln IS NOT INITIAL.
      zcl_mm_r002_service=>write_log(
        it_ebeln  = lt_ebeln
        iv_commit = abap_false ).
    ENDIF.
  ENDMETHOD.

  METHOD cleanup.
    lcl_print_buffer=>consume( ).
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.
ENDCLASS.
