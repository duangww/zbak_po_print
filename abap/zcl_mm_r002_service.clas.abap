CLASS zcl_mm_r002_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_sel,
             ebeln  TYPE RANGE OF ekko-ebeln,
             bedat  TYPE RANGE OF ekko-bedat,
             ekgrp  TYPE RANGE OF ekko-ekgrp,
             lifnr  TYPE RANGE OF ekko-lifnr,
             ekorg  TYPE RANGE OF ekko-ekorg,
             werks  TYPE RANGE OF ekpo-werks,
             noshow TYPE abap_bool,
           END OF ty_sel.

    TYPES: BEGIN OF ty_list.
             INCLUDE TYPE zmm_r002_h.
    TYPES:   log TYPE abap_bool,
           END OF ty_list.
    TYPES tt_list TYPE STANDARD TABLE OF ty_list WITH EMPTY KEY.

    TYPES: BEGIN OF ty_item,
             ebeln      TYPE ekpo-ebeln,
             ebelp      TYPE ekpo-ebelp,
             matnr      TYPE ekpo-matnr,
             txz01      TYPE ekpo-txz01,
             groes      TYPE mara-groes,
             menge      TYPE ekpo-menge,
             meins      TYPE ekpo-meins,
             price      TYPE zmm_r002_i-price,
             price_text TYPE c LENGTH 19,
             netpr      TYPE ekpo-netpr,
             effwr2     TYPE ekpo-effwr,
             netwr      TYPE ekpo-netwr,
             effwr      TYPE ekpo-effwr,
             kzwi1      TYPE ekpo-kzwi1,
             effwr_text TYPE c LENGTH 16,
             eindt      TYPE eket-eindt,
             mwskz      TYPE ekpo-mwskz,
             waers      TYPE ekko-waers,
             werks      TYPE ekpo-werks,
             remark     TYPE zmm_r002_i-remark,
           END OF ty_item.
    TYPES tt_item    TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.
    TYPES tt_header  TYPE STANDARD TABLE OF zmm_r002_h WITH EMPTY KEY.
    TYPES tt_ebeln   TYPE STANDARD TABLE OF ebeln WITH EMPTY KEY.
    TYPES tt_otf     TYPE STANDARD TABLE OF itcoo WITH DEFAULT KEY.

    CONSTANTS gc_form_default TYPE tdsfname VALUE 'ZMM_R002_03B'.
    CONSTANTS gc_form_special TYPE tdsfname VALUE 'ZMM_R002_02'.

    CLASS-METHODS get_po_data
      IMPORTING
        is_sel    TYPE ty_sel
      EXPORTING
        et_list   TYPE tt_list
        et_header TYPE tt_header
        et_item   TYPE tt_item.

    CLASS-METHODS get_pdf
      IMPORTING
        it_ebeln  TYPE tt_ebeln
        iv_formid TYPE tdsfname OPTIONAL
      EXPORTING
        ev_pdf    TYPE xstring
        ev_fname  TYPE string
        ev_error  TYPE string.

    CLASS-METHODS write_log
      IMPORTING
        it_ebeln  TYPE tt_ebeln
        iv_commit TYPE abap_bool DEFAULT abap_true.

    CLASS-METHODS parse_ebeln_list
      IMPORTING
        iv_ebelns      TYPE clike
      RETURNING
        VALUE(rt_ebeln) TYPE tt_ebeln.

  PRIVATE SECTION.
    CLASS-METHODS read_text
      IMPORTING
        iv_name      TYPE tdobname
        iv_tdid      TYPE tdid
        iv_tdobject  TYPE tdobject
        iv_langu     TYPE thead-tdspras
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS get_multi_fkfs
      IMPORTING
        iv_lifnr TYPE lifnr
        iv_bukrs TYPE bukrs
      RETURNING
        VALUE(rv_ztext) TYPE text1_042z.

    CLASS-METHODS convert_otf_to_pdf
      IMPORTING
        it_otf         TYPE tt_otf
      EXPORTING
        ev_pdf         TYPE xstring
        ev_error       TYPE string.
ENDCLASS.


CLASS zcl_mm_r002_service IMPLEMENTATION.

  METHOD parse_ebeln_list.
    DATA lv_rest  TYPE string.
    DATA lv_token TYPE string.
    DATA lv_ebeln TYPE ebeln.

    lv_rest = iv_ebelns.
    CONDENSE lv_rest.
    REPLACE ALL OCCURRENCES OF `,` IN lv_rest WITH `;`.
    REPLACE ALL OCCURRENCES OF ` ` IN lv_rest WITH `;`.

    WHILE lv_rest IS NOT INITIAL.
      SPLIT lv_rest AT `;` INTO lv_token lv_rest.
      CONDENSE lv_token.
      CHECK lv_token IS NOT INITIAL.
      CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
        EXPORTING
          input  = lv_token
        IMPORTING
          output = lv_ebeln.
      APPEND lv_ebeln TO rt_ebeln.
    ENDWHILE.

    SORT rt_ebeln.
    DELETE ADJACENT DUPLICATES FROM rt_ebeln.
  ENDMETHOD.

  METHOD get_po_data.
    DATA: lv_tax           TYPE konp-kbetr,
          lv_kbetr         TYPE konp-kbetr,
          lv_name          TYPE tdobname,
          lv_factor        TYPE isoc_factor,
          lv_kbetr2        TYPE prcd_elements-kbetr,
          lw_prcd_elements TYPE prcd_elements,
          lv_text          TYPE string.

    DATA: lt_ekko TYPE STANDARD TABLE OF ekko,
          ls_ekko TYPE ekko,
          lt_ekpo TYPE STANDARD TABLE OF ekpo,
          ls_ekpo TYPE ekpo,
          lt_log  TYPE STANDARD TABLE OF zmm_print_log,
          ls_log  TYPE zmm_print_log.

    DATA: ls_header TYPE zmm_r002_h,
          ls_list   TYPE ty_list,
          ls_item   TYPE ty_item.

    CLEAR: et_list, et_header, et_item.

    SELECT ebeln bukrs ekgrp ekorg lifnr bedat waers zterm knumv bsart
      FROM ekko
      INTO CORRESPONDING FIELDS OF TABLE lt_ekko
      WHERE ebeln IN is_sel-ebeln
        AND bedat IN is_sel-bedat
        AND ekgrp IN is_sel-ekgrp
        AND lifnr IN is_sel-lifnr
        AND ekorg IN is_sel-ekorg
        AND loekz  = ''.
    IF lt_ekko IS INITIAL.
      RETURN.
    ENDIF.

    SELECT ebeln ebelp matnr txz01 menge meins netpr effwr kzwi1 mwskz werks netwr
      FROM ekpo
      INTO CORRESPONDING FIELDS OF TABLE lt_ekpo
      FOR ALL ENTRIES IN lt_ekko
      WHERE ebeln = lt_ekko-ebeln
        AND werks IN is_sel-werks
        AND loekz  = ''
        AND retpo  = ''.
    IF lt_ekpo IS INITIAL.
      RETURN.
    ENDIF.

    SELECT * FROM zmm_print_log INTO TABLE lt_log
      WHERE flag = 'X'
        AND r002 = 'X'.
    SORT lt_log BY ebeln.

    SORT: lt_ekko BY ebeln,
          lt_ekpo BY ebeln ebelp.

    LOOP AT lt_ekpo INTO ls_ekpo.
      READ TABLE lt_ekko INTO ls_ekko WITH KEY ebeln = ls_ekpo-ebeln BINARY SEARCH.
      IF sy-subrc = 0.
        MOVE-CORRESPONDING ls_ekko TO ls_header.
      ENDIF.

      SELECT SINGLE butxt FROM t001 INTO ls_header-butxt WHERE bukrs = ls_header-bukrs.
      SELECT SINGLE stras FROM t001w INTO ls_header-stras WHERE werks = ls_ekpo-werks.

      CLEAR lv_text.
      lv_name = ls_ekpo-ebeln.
      lv_text = read_text( iv_name = lv_name iv_tdid = 'F01' iv_tdobject = 'EKKO' iv_langu = '1' ).
      IF lv_text IS NOT INITIAL.
        ls_header-dhdzt = lv_text.
      ENDIF.

      SELECT SINGLE a~name1 b~fax_number
        FROM lfa1 AS a INNER JOIN adrc AS b ON a~adrnr = b~addrnumber
        INTO (ls_header-name1, ls_header-fax_number)
        WHERE a~lifnr = ls_header-lifnr.

      SELECT SINGLE telf1 verkf
        FROM lfm1
        INTO (ls_header-telf1, ls_header-verkf)
        WHERE lifnr = ls_header-lifnr
          AND ekorg = ls_header-ekorg.

      lv_text = read_text( iv_name = lv_name iv_tdid = 'F02' iv_tdobject = 'EKKO' iv_langu = '1' ).
      IF lv_text IS NOT INITIAL.
        ls_header-ztext = CONV #( lv_text ).
      ELSE.
        ls_header-ztext = get_multi_fkfs( iv_lifnr = ls_ekko-lifnr iv_bukrs = ls_ekko-bukrs ).
      ENDIF.

      ls_header-zterm = ls_ekko-zterm.
      SELECT SINGLE text1 FROM t052u INTO ls_header-text1
        WHERE zterm = ls_ekko-zterm
          AND spras = '1'.

      SELECT SINGLE a~kbetr
        FROM konp AS a
        INNER JOIN a003 AS b ON a~knumh = b~knumh
        INNER JOIN t001 AS c ON b~aland = c~land1
        INTO lv_kbetr
        WHERE b~mwskz = ls_ekpo-mwskz
          AND c~bukrs = ls_ekko-bukrs.
      lv_kbetr = lv_kbetr / 1000.
      lv_tax   = lv_kbetr.
      ls_header-tax = lv_tax.
      lv_tax = lv_tax * 100.
      ls_header-tax_text = lv_tax.

      CLEAR ls_item.
      MOVE-CORRESPONDING ls_ekpo TO ls_item.

      CALL FUNCTION 'CURRENCY_CONVERTING_FACTOR'
        EXPORTING
          currency = ls_header-waers
        IMPORTING
          factor   = lv_factor.
      IF sy-subrc = 0.
        ls_item-kzwi1 = ls_item-kzwi1 * lv_factor.
      ENDIF.

      CLEAR lv_kbetr2.
      SELECT SINGLE * INTO CORRESPONDING FIELDS OF lw_prcd_elements
        FROM prcd_elements
        WHERE knumv = ls_ekko-knumv
          AND kschl = 'PB00'
          AND kposn = ls_ekpo-ebelp.
      IF sy-subrc = 0.
        ls_item-price = lw_prcd_elements-kbetr / lw_prcd_elements-kpein.
      ELSE.
        SELECT SINGLE * INTO CORRESPONDING FIELDS OF lw_prcd_elements
          FROM prcd_elements
          WHERE knumv = ls_ekko-knumv
            AND kschl = 'PBXX'
            AND kposn = ls_ekpo-ebelp.
        IF sy-subrc = 0.
          ls_item-price = lw_prcd_elements-kbetr / lw_prcd_elements-kpein.
        ELSE.
          IF ls_item-menge > 0.
            ls_item-price = ls_item-kzwi1 / ls_item-menge.
          ELSE.
            ls_item-price = ls_item-kzwi1.
          ENDIF.
        ENDIF.
      ENDIF.

      SELECT SINGLE kbetr INTO lv_kbetr2
        FROM prcd_elements
        WHERE knumv = ls_ekko-knumv
          AND kschl = 'Z003'
          AND kposn = ls_ekpo-ebelp.
      IF sy-subrc = 0.
        ls_item-kzwi1 = ls_item-price * ls_item-menge.
      ENDIF.

      ls_item-price_text = ls_item-price.
      ls_item-effwr      = ls_item-kzwi1.
      ls_item-effwr_text = ls_item-kzwi1.

      SELECT SINGLE eindt FROM eket INTO ls_item-eindt
        WHERE ebeln = ls_item-ebeln
          AND ebelp = ls_item-ebelp
          AND etenr = 1.

      ls_item-waers = ls_header-waers.

      CONCATENATE ls_ekpo-ebeln ls_ekpo-ebelp INTO lv_name.
      ls_item-remark = CONV #( read_text(
        iv_name     = lv_name
        iv_tdid     = 'F01'
        iv_tdobject = 'EKPO'
        iv_langu    = '1' ) ).
      CLEAR lv_name.

      SELECT SINGLE groes INTO ls_item-groes FROM mara WHERE matnr = ls_ekpo-matnr.
      IF sy-subrc <> 0.
        CLEAR ls_item-groes.
      ENDIF.

      ls_item-effwr2 = ls_item-netwr.
      APPEND ls_item TO et_item.

      ls_header-sum_menge = ls_header-sum_menge + ls_item-menge.
      ls_header-sum_menge_text = ls_header-sum_menge.
      ls_header-sum_effwr = ls_header-sum_effwr + ls_item-kzwi1.
      ls_header-sum_effwr_text = ls_header-sum_effwr.
      ls_header-sum_effwr2 = ls_header-sum_effwr2 + ls_item-effwr2.
      WRITE ls_header-sum_effwr2 TO ls_header-sum_effwr2_text
        CURRENCY ls_header-waers
        DECIMALS 2.
      CONDENSE ls_header-sum_effwr2_text.

      AT END OF ebeln.
        READ TABLE lt_log INTO ls_log WITH KEY ebeln = ls_header-ebeln BINARY SEARCH.
        IF sy-subrc = 0.
          IF is_sel-noshow <> abap_true.
            ls_list = CORRESPONDING #( ls_header ).
            ls_list-log = abap_true.
            APPEND ls_list TO et_list.
            APPEND ls_header TO et_header.
          ENDIF.
        ELSE.
          ls_list = CORRESPONDING #( ls_header ).
          CLEAR ls_list-log.
          APPEND ls_list TO et_list.
          APPEND ls_header TO et_header.
        ENDIF.
        CLEAR ls_header.
      ENDAT.
    ENDLOOP.

    SORT: et_header BY ebeln,
          et_item   BY ebeln ebelp,
          et_list   BY ebeln.
  ENDMETHOD.

  METHOD get_pdf.
    DATA: ls_sel      TYPE ty_sel,
          lt_list     TYPE tt_list,
          lt_header   TYPE tt_header,
          lt_item     TYPE tt_item,
          lt_head_i   TYPE TABLE OF zmm_r002_h,
          lt_item_i   TYPE TABLE OF zmm_r002_i,
          ls_item     TYPE ty_item,
          ls_item_i   TYPE zmm_r002_i,
          ls_head     TYPE zmm_r002_h,
          lv_formid   TYPE tdsfname,
          lv_fm       TYPE rs38l_fnam,
          ls_ctrl     TYPE ssfctrlop,
          ls_out      TYPE ssfcompop,
          ls_info     TYPE ssfcrescl,
          lt_equip    TYPE TABLE OF zmm_r002_e,
          lv_ebeln    TYPE ebeln,
          lv_flag     TYPE i.

    CLEAR: ev_pdf, ev_fname, ev_error.

    IF it_ebeln IS INITIAL.
      ev_error = '请选择需要打印的采购订单'.
      RETURN.
    ENDIF.

    lv_formid = iv_formid.
    IF lv_formid IS INITIAL.
      lv_formid = gc_form_default.
    ENDIF.

    LOOP AT it_ebeln INTO lv_ebeln.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_ebeln ) TO ls_sel-ebeln.
    ENDLOOP.
    ls_sel-noshow = abap_false.

    get_po_data(
      EXPORTING is_sel    = ls_sel
      IMPORTING et_list   = lt_list
                et_header = lt_header
                et_item   = lt_item ).

    IF lt_header IS INITIAL.
      ev_error = '未查询到符合条件的数据'.
      RETURN.
    ENDIF.

    READ TABLE it_ebeln INTO lv_ebeln INDEX 1.
    ev_fname = |PO_{ lv_ebeln }.pdf|.

    ls_ctrl-no_open   = abap_true.
    ls_ctrl-no_close  = abap_true.
    ls_ctrl-no_dialog = abap_true.
    ls_ctrl-getotf    = abap_true.
    ls_ctrl-preview   = abap_false.

    ls_out-tddest   = 'LP01'.
    ls_out-tdimmed  = abap_true.
    ls_out-tddelete = abap_true.
    ls_out-tdnewid  = abap_true.

    CALL FUNCTION 'SSF_OPEN'
      EXPORTING
        user_settings      = space
        output_options     = ls_out
        control_parameters = ls_ctrl
      EXCEPTIONS
        formatting_error   = 1
        internal_error     = 2
        send_error         = 3
        user_canceled      = 4
        OTHERS             = 5.
    IF sy-subrc <> 0.
      ev_error = '打开打印请求失败'.
      RETURN.
    ENDIF.

    CALL FUNCTION 'SSF_FUNCTION_MODULE_NAME'
      EXPORTING
        formname           = lv_formid
      IMPORTING
        fm_name            = lv_fm
      EXCEPTIONS
        no_form            = 1
        no_function_module = 2
        OTHERS             = 3.
    IF sy-subrc <> 0 OR lv_fm IS INITIAL.
      ev_error = |找不到表单 { lv_formid }|.
      CALL FUNCTION 'SSF_CLOSE'.
      RETURN.
    ENDIF.

    SORT lt_item BY ebeln ebelp.

    LOOP AT lt_header INTO ls_head.
      CLEAR: lt_head_i, lt_item_i.
      APPEND ls_head TO lt_head_i.

      READ TABLE lt_item TRANSPORTING NO FIELDS
        WITH KEY ebeln = ls_head-ebeln BINARY SEARCH.
      IF sy-subrc = 0.
        LOOP AT lt_item INTO ls_item FROM sy-tabix.
          IF ls_item-ebeln <> ls_head-ebeln.
            EXIT.
          ENDIF.
          CLEAR ls_item_i.
          MOVE-CORRESPONDING ls_item TO ls_item_i.
          WRITE ls_item_i-effwr2 TO ls_item_i-effwr2_text
            CURRENCY ls_item_i-waers
            DECIMALS 2.
          CONDENSE ls_item_i-effwr2_text.
          APPEND ls_item_i TO lt_item_i.
        ENDLOOP.
      ENDIF.

      IF lv_formid = gc_form_special.
        CALL FUNCTION lv_fm
          EXPORTING
            control_parameters = ls_ctrl
          TABLES
            gt_head            = lt_head_i
            gt_item            = lt_item_i
            gt_equipment       = lt_equip
          EXCEPTIONS
            formatting_error   = 1
            internal_error     = 2
            send_error         = 3
            user_canceled      = 4
            OTHERS             = 5.
      ELSE.
        CALL FUNCTION lv_fm
          EXPORTING
            control_parameters = ls_ctrl
          TABLES
            gt_head            = lt_head_i
            gt_item            = lt_item_i
          EXCEPTIONS
            formatting_error   = 1
            internal_error     = 2
            send_error         = 3
            user_canceled      = 4
            OTHERS             = 5.
      ENDIF.
    ENDLOOP.

    CALL FUNCTION 'SSF_CLOSE'
      IMPORTING
        job_output_info  = ls_info
      EXCEPTIONS
        formatting_error = 1
        internal_error   = 2
        send_error       = 3
        OTHERS           = 4.

    DATA lt_otf TYPE tt_otf.
    lt_otf = ls_info-otfdata.
    IF lt_otf IS INITIAL.
      ev_error = 'SmartForms 未返回 OTF'.
      RETURN.
    ENDIF.

    convert_otf_to_pdf(
      EXPORTING it_otf   = lt_otf
      IMPORTING ev_pdf   = ev_pdf
                ev_error = ev_error ).
  ENDMETHOD.

  METHOD write_log.
    DATA: lv_num  TYPE zmm_print_log-logno,
          ls_log  TYPE zmm_print_log,
          lt_log  TYPE STANDARD TABLE OF zmm_print_log,
          lv_ebeln TYPE ebeln.

    LOOP AT it_ebeln INTO lv_ebeln.
      CHECK lv_ebeln IS NOT INITIAL.
      CLEAR ls_log.
      CALL FUNCTION 'NUMBER_GET_NEXT'
        EXPORTING
          nr_range_nr             = '01'
          object                  = 'ZPRINTLOG'
        IMPORTING
          number                  = lv_num
        EXCEPTIONS
          interval_not_found      = 1
          number_range_not_intern = 2
          object_not_found        = 3
          quantity_is_0           = 4
          quantity_is_not_1       = 5
          interval_overflow       = 6
          buffer_overflow         = 7
          OTHERS                  = 8.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      ls_log-logno = lv_num.
      ls_log-ebeln = lv_ebeln.
      ls_log-puser = sy-uname.
      ls_log-pdate = sy-datum.
      ls_log-flag  = 'X'.
      ls_log-r002  = 'X'.
      APPEND ls_log TO lt_log.
    ENDLOOP.

    IF lt_log IS NOT INITIAL.
      MODIFY zmm_print_log FROM TABLE lt_log.
      IF iv_commit = abap_true.
        COMMIT WORK.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD convert_otf_to_pdf.
    DATA: lv_size  TYPE i,
          lt_lines TYPE TABLE OF tline,
          lt_otf   TYPE STANDARD TABLE OF itcoo.

    CLEAR: ev_pdf, ev_error.
    lt_otf = it_otf.

    CALL FUNCTION 'CONVERT_OTF'
      EXPORTING
        format                = 'PDF'
      IMPORTING
        bin_filesize          = lv_size
        bin_file              = ev_pdf
      TABLES
        otf                   = lt_otf
        lines                 = lt_lines
      EXCEPTIONS
        err_max_linewidth     = 1
        err_format            = 2
        err_conv_not_possible = 3
        err_bad_otf           = 4
        OTHERS                = 5.
    IF sy-subrc <> 0 OR ev_pdf IS INITIAL.
      ev_error = 'OTF 转 PDF 失败'.
    ENDIF.
  ENDMETHOD.

  METHOD read_text.
    DATA: ls_stxh  TYPE stxh,
          lt_lines TYPE TABLE OF tline,
          ls_line  TYPE tline.

    CLEAR rv_text.

    SELECT SINGLE * INTO ls_stxh FROM stxh
      WHERE tdobject = iv_tdobject
        AND tdname   = iv_name
        AND tdid     = iv_tdid
        AND tdspras  = sy-langu.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CALL FUNCTION 'READ_TEXT'
      EXPORTING
        id       = iv_tdid
        language = iv_langu
        name     = iv_name
        object   = iv_tdobject
      TABLES
        lines    = lt_lines
      EXCEPTIONS
        OTHERS   = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    LOOP AT lt_lines INTO ls_line.
      CONCATENATE rv_text ls_line-tdline INTO rv_text SEPARATED BY space.
    ENDLOOP.
    CONDENSE rv_text NO-GAPS.
  ENDMETHOD.

  METHOD get_multi_fkfs.
    DATA: lv_str1  TYPE string,
          lv_zwels TYPE string,
          lv_len   TYPE i,
          lv_index TYPE i.

    TYPES: BEGIN OF ty_fkfs,
             zlsch TYPE t042e-zlsch,
             text1 TYPE t042z-text1,
           END OF ty_fkfs.
    DATA: lt_fkfs TYPE STANDARD TABLE OF ty_fkfs,
          ls_fkfs TYPE ty_fkfs.

    CLEAR rv_ztext.

    SELECT SINGLE zwels
      FROM lfb1
      INTO lv_zwels
      WHERE lifnr = iv_lifnr
        AND bukrs = iv_bukrs.
    IF lv_zwels IS INITIAL.
      RETURN.
    ENDIF.

    lv_len = strlen( lv_zwels ).
    DO lv_len TIMES.
      SELECT DISTINCT a~zlsch, c~text1
        APPENDING CORRESPONDING FIELDS OF TABLE @lt_fkfs
        FROM t042e AS a
        INNER JOIN t001 AS b ON a~zbukr = b~bukrs
        INNER JOIN t042z AS c ON c~land1 = b~land1 AND c~zlsch = a~zlsch
        WHERE a~zbukr = @iv_bukrs
          AND a~zlsch = @lv_zwels+lv_index(1).
      lv_index = lv_index + 1.
    ENDDO.

    LOOP AT lt_fkfs INTO ls_fkfs.
      lv_str1 = lv_str1 && ls_fkfs-text1 && '或'.
    ENDLOOP.
    SHIFT lv_str1 RIGHT DELETING TRAILING '或'.
    CONDENSE lv_str1 NO-GAPS.
    rv_ztext = CONV #( lv_str1 ).
  ENDMETHOD.

ENDCLASS.
