SELECT 
    -- PR
    PD.DISTRIBUTION_ID,
    PD.PR_Number,
    PD.PR_Description,
    PD.PR_Creation_Date,
    PD.PR_Status,
    PD.PR_Line_No,
    PD.PR_Quantity,
    PD.Unit_Price,
    PD.PR_Line_Amount_OMR,
    PD.Currency,
    PD.RUSH_FLAG,
    PD.NEED_BY_DATE,
    PD."PR Latest Approved Date",
    PD."PR Original Approved Date",
    PD."Item Code",
    PD."Item Description",
    PD."Item Type",
    PD."Sourced Or Unsourced",
    PD."PR Requestor",
    PD."PR Approval Pending With",

    -- RFQ
    AD.DOCUMENT_NUMBER as "RFQ Number",
    AD.AUCTION_STATUS as "RFQ Status",
    AD.AUCTION_ORIGINATION_CODE as "RFQ Type",
    AD.CREATION_DATE as "RFQ Creation Date",
    AD.CLOSE_BIDDING_DATE as "RFQ Closed Date",
    AD.INT_ATTRIBUTE6 as "RFQ Strategy",
    AD.INT_ATTRIBUTE4 as "TE Date",
    AD.AWARD_DATE as "RFQ Award Date",
    AD.RFQ_SUBMIT_DATE as "RFQ Submit Date",
    AD.PUBLISH_DATE as "RFQ Publish Date",
    AD.FULL_NAME as "Buyer Name",
    null as "RFQ Stage",

    -- PO
    PHA.segment1 AS "PO Number",
    PDA.REQ_DISTRIBUTION_ID as "RID",
    PLA.line_num AS "PO Line",
    PHA.comments AS "PO Header Description", -- Added
    PLA.item_description AS "PO Line Description", -- Changed
    PHA.type_lookup_code AS "PO Type (Blanket/Standard)",
    PHA.creation_date AS "PO Creation Date",
    PHA.approved_date AS "PO Latested Approved Date",
    (
        SELECT MIN(ACTION_DATE) FROM po_action_history 
        WHERE object_id = PHA.po_header_id 
        AND ACTION_CODE = 'APPROVE' 
        AND OBJECT_TYPE_CODE = 'PO'
    ) AS "PO Original Approved Date",
    PHA.authorization_status AS "PO Status",
    null AS "BR Number - Blanket",
    null AS "BR Approved Date - Blanket",
    null AS "BR_ORIGINAL_APPROVED_DATE",
    null AS "BR Status - Blanket",
    -- ADD AGAIN *
    null AS "CH Name (Contract Holder) - Blanket",
    -- ADD AGAIN *
    null AS "CE Name (Contract Engineer) - Blanket",
    (
        SELECT VENDOR_NAME FROM AP_SUPPLIERS 
        WHERE VENDOR_ID = PHA.VENDOR_ID
    ) AS "Supplier Name",
    (
        GCC.segment1 || '.' || GCC.segment2 || '.' || GCC.segment3 || '.' || GCC.segment4 || '.' || 
        GCC.segment5 || '.' || GCC.segment6 || '.' || GCC.segment7 
    ) AS "GL Code Combination",
    WE.wip_entity_name AS "WO Number",
    PPA.segment1 AS "Project Number",
    (select MAX(amount_limit) from po_headers_archive_all PHHA where segment1 = PHA.SEGMENT1) AS "ACV AMOUNT",
    PLLA.quantity AS "PO Order Qty",
    (PLLA.price_override * PLLA.quantity) AS "PO Order Amount", -- Changed
    CASE
        WHEN NVL(PHA.rate, 0) = 0 THEN PLLA.price_override * PLLA.quantity
        ELSE ROUND((PLLA.price_override * PLLA.quantity) / NVL(PHA.rate, 1), 2)
    END AS "PO Order Amount (USD)", -- changed

    (
        SELECT papf1.full_name
        FROM po_action_history pah1
        JOIN po_releases_all pha1 ON pah1.object_id = pha1.po_release_id
        JOIN per_all_people_f papf1 ON pah1.employee_id = papf1.person_id
        WHERE    
            SYSDATE BETWEEN papf1.effective_start_date AND papf1.effective_end_date
            AND pha1.authorization_status NOT IN ('APPROVED', 'REJECTED', 'INCOMPLETE')
            AND pah1.sequence_num = (SELECT MAX (aa1.sequence_num) 
                                      FROM po_action_history aa1 
                                      WHERE aa1.object_id = pah1.object_id)
            AND pah1.OBJECT_TYPE_CODE='STANDARD'
            AND PHA.PO_HEADER_ID = pha1.PO_HEADER_ID
    ) AS "PO approval Pending with",
    (
        SELECT papf1.employee_number
        FROM po_action_history pah1
        JOIN po_releases_all pha1 ON pah1.object_id = pha1.po_release_id
        JOIN per_all_people_f papf1 ON pah1.employee_id = papf1.person_id
        WHERE    
            SYSDATE BETWEEN papf1.effective_start_date AND papf1.effective_end_date
            AND pha1.authorization_status NOT IN ('APPROVED', 'REJECTED', 'INCOMPLETE')
            AND pah1.sequence_num = (SELECT MAX (aa1.sequence_num) 
                                      FROM po_action_history aa1 
                                      WHERE aa1.object_id = pah1.object_id)
            AND pah1.OBJECT_TYPE_CODE='STANDARD'
            AND PHA.PO_HEADER_ID = pha1.PO_HEADER_ID
    ) AS "PO approval Pending with Employee Id",
    
    -- Receipt
    RSH.receipt_num as "Receipt Number",
    RSH.creation_date AS "Receipt Date",
    RSL.line_num as "Receipt line No",
    RT.quantity as "Receipt Qty",
    (PLLA.price_override * RT.QUANTITY) AS "Receipt Amount",
    NVL(RT.CURRENCY_CODE, 'USD') AS "Currency",
    CASE
        WHEN NVL(RT.CURRENCY_CONVERSION_RATE, 0) = 0 THEN PLLA.price_override * RT.QUANTITY
        ELSE ROUND((PLLA.price_override * RT.QUANTITY) / NVL(RT.CURRENCY_CONVERSION_RATE, 1), 2)
    END AS "Receipt Amount (USD)",
    -- (SELECT user_name from fnd_user where user_id=RSL.last_updated_by) as "Received By",
    (select FULL_NAME from fnd_user fu join per_all_people_f papf on fu.user_id=papf.person_id
    AND TRUNC(RSL.LAST_UPDATE_DATE) BETWEEN papf.effective_start_date AND papf.effective_end_date and fu.user_id=RSL.last_updated_by)
    as "Received By", -- changed

    -- Inspection
    CASE WHEN PLLA.RECEIVING_ROUTING_ID = 2 THEN 'Yes' ELSE 'No' END AS "Inspection Flag",
    CASE WHEN RT.TRANSACTION_TYPE='ACCEPT' OR RT.TRANSACTION_TYPE='REJECT' THEN RT.TRANSACTION_DATE ELSE NULL END AS "Inspection Date",
    CASE WHEN RT.TRANSACTION_TYPE='ACCEPT' OR RT.TRANSACTION_TYPE='REJECT' THEN RT.TRANSACTION_TYPE ELSE NULL END AS "Inspection STATUS",
    CASE 
        WHEN PD.ITEM_ID IS NULL AND PD.ATTRIBUTE2 IS NOT NULL 
        THEN PD.ATTRIBUTE2
        ELSE PD.ATTRIBUTE1  -- Reference PD.ATTRIBUTE1 instead of MSIB.ATTRIBUTE1
    END as "Inspection Group",

    (
        SELECT LISTAGG(papf.email_address, ', ') WITHIN GROUP (ORDER BY papf.email_address)
        FROM rcv_transactions rt_inner
        JOIN rcv_shipment_headers rsh_inner 
            ON rsh_inner.shipment_header_id = rt_inner.shipment_header_id
        JOIN rcv_shipment_lines rsl_inner 
            ON rsl_inner.shipment_line_id = rt_inner.shipment_line_id
        LEFT JOIN mtl_system_items_b msib 
            ON rsl_inner.item_id = msib.inventory_item_id 
            AND rt_inner.organization_id = msib.organization_id
        LEFT JOIN PO_REQUISITION_LINES_ALL PORL 
            ON rt_inner.po_line_id = PORL.REQUISITION_LINE_ID
        JOIN per_all_positions pap 
            ON 1=1  -- Need to specify join condition if required
        JOIN per_position_definitions ppd 
            ON pap.position_definition_id = ppd.position_definition_id
        JOIN per_all_assignments_f paaf 
            ON pap.position_id = paaf.position_id
            AND TRUNC(SYSDATE) BETWEEN paaf.effective_start_date AND paaf.effective_end_date
        JOIN per_all_people_f papf 
            ON paaf.person_id = papf.person_id
            AND TRUNC(SYSDATE) BETWEEN papf.effective_start_date AND papf.effective_end_date
        WHERE rt_inner.transaction_id = RT.transaction_id
        AND rt_inner.transaction_type = 'RECEIVE'
        AND rt_inner.routing_header_id = '2'
        AND (msib.inspection_required_flag = 'Y' OR PORL.attribute2 IS NOT NULL)
        AND rt_inner.quantity > (
            NVL((
                SELECT SUM(rt2.quantity)
                FROM rcv_transactions rt2
                WHERE rt2.parent_transaction_id = rt_inner.transaction_id
                AND rt2.transaction_type IN ('ACCEPT', 'REJECT')
            ), 0)
        )
        AND UPPER(TRIM(ppd."SEGMENT3#1")) IN (
            SELECT UPPER(tag)
            FROM fnd_lookup_values
            WHERE lookup_type = 'XXOLNG_INSPECTION_GROUP'
            AND language = 'US'
            AND enabled_flag = 'Y'
            AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(start_date_active, SYSDATE))
                AND TRUNC(NVL(end_date_active, SYSDATE))
            AND UPPER(description) = UPPER(COALESCE(msib.attribute1, PORL.attribute2))
        )
        AND NOT EXISTS (
            SELECT 1 
            FROM rcv_transactions rt1 
            WHERE rt1.parent_transaction_id = rt_inner.transaction_id 
            AND rt1.transaction_type IN ('RETURN TO VENDOR', 'REJECT', 'TRANSFER')
        )
    ) as "Inspection Pending With",

    -- Delievery
    CASE WHEN RT.TRANSACTION_TYPE = 'DELIVER' THEN RT.TRANSACTION_DATE ELSE NULL END AS "Delivery Date",
    CASE WHEN RT.TRANSACTION_TYPE = 'DELIVER' THEN RT.TRANSACTION_TYPE ELSE NULL END AS "Delivery Status",

    -- -- QS - SRN
    null AS "SRN Number",
    null AS "SRN Desc",
    null AS "SRN Creation Date",
    null AS "SRN Approved/Reject Date",
    null AS "SRN Status",
    null AS "SRN Comments",
    null AS "Requestor Qty",
    null AS "Supplier Qty",
    null AS "QS Qty",

    -- -- QS - VRN
    null AS "VRN Number",
    null AS "VRN Desc",
    null AS "VRN Creation Date",
    null AS "VRN Approved/Reject Date",
    null AS "VRN Status",
    null AS "VRN Verified Amount",
    null AS "QS NAME",
    null AS "QS COMMENTS",

    -- INVOICE
    AIA.invoice_num AS "Invoice Number",
    AILA.line_number AS "Invoice Line",  
    AIDA.LINE_TYPE_LOOKUP_CODE AS "Invoice Line Type",
    AIA.invoice_date AS "Invoice Approved date",
    AIA.creation_date AS "Invoice create date",
    CASE
        WHEN AIA.payment_status_flag = 'Y' THEN 'Paid'
        WHEN AIA.approval_ready_flag = 'Y' THEN 'Ready for Approval' 
        WHEN AIA.approval_ready_flag = 'N' THEN 'Not Ready for Approval'
        ELSE null
    END AS "Invoice Status",
    CASE  
        WHEN AIDA.match_status_flag = 'A' THEN 'Validated'
        WHEN AIDA.match_status_flag = 'R' THEN 'Needs Revalidation'
        ELSE 'Never Validated' 
    END AS "Match Status Flag",
    AIA.exchange_rate as "Exchange Rate",
    AIDA.amount AS "Invoice Amount",
    CASE
        WHEN NVL(AIA.exchange_rate, 0) = 0 THEN NULL
        ELSE ROUND(AIDA.amount / NVL(AIA.exchange_rate, 1), 2)
    END AS "Invoice Amount USD", -- changed
    
    -- PAYMENTS
    ACA.check_date as "Payment Date",
    ACA.amount as "Payment Amount",
    APSA.due_date as "Payment Due Date",
    APSA.PAYMENT_STATUS_FLAG as "Payment Status"

FROM
     po_headers_all PHA
JOIN po_lines_all PLA ON PHA.po_header_id = PLA.po_header_id AND PHA.TYPE_LOOKUP_CODE='STANDARD'
JOIN po_line_locations_all PLLA ON PLA.po_line_id = PLLA.po_line_id
-- LEFT JOIN po_releases_all PRA ON PLLA.po_release_id = PRA.po_release_id

-- ADDED LEFT JOIN WITH rcv_transactions TO GET RECORDS WITHOUT rcv_transactions
LEFT JOIN rcv_transactions RT ON RT.po_header_id = PHA.po_header_id 
AND PLA.PO_LINE_ID=RT.PO_LINE_ID 
AND PLLA.LINE_LOCATION_ID=RT.PO_LINE_LOCATION_ID
-- AND RT.PO_RELEASE_ID = PRA.PO_RELEASE_ID 
LEFT JOIN rcv_shipment_lines RSL ON RSL.shipment_line_id = RT.shipment_line_id
LEFT JOIN rcv_shipment_headers RSH ON RSH.shipment_header_id = RSL.shipment_header_id
LEFT JOIN po_distributions_all PDA ON PLLA.line_location_id = PDA.line_location_id 
-- inspection records were not included with this condition
-- AND RT.PO_DISTRIBUTION_ID=PDA.PO_DISTRIBUTION_ID

FULL OUTER JOIN 
(
    SELECT 
    -- JOIN COLS
    PORD.DISTRIBUTION_ID AS DISTRIBUTION_ID,

    -- PR INFO
    PORHA.SEGMENT1 AS PR_Number,
    PORHA.DESCRIPTION AS PR_Description,
    PORHA.CREATION_DATE AS PR_Creation_Date,
    PORHA.AUTHORIZATION_STATUS AS PR_Status,

    -- PR Line Info
    PORLA.LINE_NUM AS PR_Line_No,
    PORLA.QUANTITY AS PR_Quantity,
    PORLA.UNIT_PRICE AS Unit_Price,
    NVL(PORLA.QUANTITY, 0) * NVL(PORLA.UNIT_PRICE, 0) AS PR_Line_Amount_OMR,
    NVL(PORLA.CURRENCY_CODE, 'USD') AS Currency,
    PORLA.URGENT_FLAG AS RUSH_FLAG,
    PORLA.NEED_BY_DATE AS NEED_BY_DATE,

    -- APPROVAL INFO
    PORHA.APPROVED_DATE AS "PR Latest Approved Date",
    (
        SELECT MIN(ACTION_DATE) FROM po_action_history 
        WHERE PORHA.requisition_header_id = object_id
        AND ACTION_CODE = 'APPROVE' 
        AND OBJECT_TYPE_CODE = 'REQUISITION'
    ) AS "PR Original Approved Date",

    -- TO DO
    MSIB.SEGMENT1 as "Item Code",
    PORLA.ITEM_ID,  -- Ensure item_id is selected
    PORLA.ATTRIBUTE2,  -- Ensure attribute2 is selected
    MSIB.ATTRIBUTE1,  -- Ensure attribute1 is selected
    PORLA.ITEM_DESCRIPTION as "Item Description",
    MSIB.ITEM_TYPE as "Item Type",
    CASE
        WHEN
            PORLA.DOCUMENT_TYPE_CODE='BLANKET'
            THEN 'SOURCED'
            ELSE 'UNSOURCED'
        END
    AS "Sourced Or Unsourced",

    PAPF.FULL_NAME as "PR Requestor",
    (
        SELECT papf1.FULL_NAME FROM 
        PO_REQUISITION_HEADERS_ALL porha1
        LEFT JOIN po_action_history pah1 ON porha1.REQUISITION_HEADER_ID = pah1.object_id 
        LEFT JOIN PER_ALL_PEOPLE_F papf1 ON pah1.employee_id = papf1.person_id
        WHERE pah1.OBJECT_TYPE_CODE='REQUISITION'
            AND pah1.action_code IS NULL
            AND pah1.sequence_num = (
                SELECT MAX (aa1.sequence_num) 
                FROM po_action_history aa1 
                WHERE aa1.object_id = pah1.object_id
            )
            AND SYSDATE BETWEEN papf1.effective_start_date AND papf1.effective_end_date
            AND porha1.AUTHORIZATION_STATUS = 'IN PROCESS'
            AND porha1.segment1 = PORHA.SEGMENT1
    ) AS "PR Approval Pending With"
    FROM
        PO_REQUISITION_HEADERS_ALL PORHA -- PR INFO
    JOIN PO_REQUISITION_LINES_ALL PORLA -- PR LINE INFO
        ON PORHA.REQUISITION_HEADER_ID = PORLA.REQUISITION_HEADER_ID
        AND NVL(PORLA.CANCEL_FLAG, 'N') != 'Y'
    LEFT JOIN PO_REQ_DISTRIBUTIONS_ALL PORD 
        ON PORLA.REQUISITION_LINE_ID = PORD.REQUISITION_LINE_ID
    LEFT JOIN MTL_SYSTEM_ITEMS_B MSIB ON PORLA.ITEM_ID = MSIB.INVENTORY_ITEM_ID 
        AND PORLA.DESTINATION_ORGANIZATION_ID=MSIB.ORGANIZATION_ID 
    LEFT JOIN PER_ALL_PEOPLE_F PAPF ON PORLA.TO_PERSON_ID = PAPF.PERSON_ID  
        AND SYSDATE BETWEEN PAPF.effective_start_date AND PAPF.effective_end_date
    WHERE PORLA.DOCUMENT_TYPE_CODE is null
) PD ON PDA.REQ_DISTRIBUTION_ID=PD.DISTRIBUTION_ID  

FULL OUTER JOIN (
    SELECT 
    ph.DOCUMENT_NUMBER as DOCUMENT_NUMBER,
    ph.AUCTION_STATUS as AUCTION_STATUS,
    ph.AUCTION_ORIGINATION_CODE as AUCTION_ORIGINATION_CODE,
    ph.CREATION_DATE as CREATION_DATE,
    ph.CLOSE_BIDDING_DATE as CLOSE_BIDDING_DATE, 
    ph.INT_ATTRIBUTE6 AS INT_ATTRIBUTE6,
    ph.INT_ATTRIBUTE4 AS INT_ATTRIBUTE4,
    ph.AWARD_DATE AS AWARD_DATE,
    prl.REQUISITION_LINE_ID as REQUISITION_LINE_ID,
    prd.DISTRIBUTION_ID as DISTRIBUTION_ID,
    prl.LINE_NUM as LINE_NUM,
    (SELECT MAX(ACTION_DATE)
     FROM pon_action_history PAH
     WHERE PAH.object_id = ph.AUCTION_HEADER_ID
       AND OBJECT_TYPE_CODE = 'NEGOTIATION'
       AND ACTION_TYPE IN ('SUBMIT')) AS RFQ_SUBMIT_DATE,
    phl.REQUISITION_NUMBER AS REQUISITION_NUMBER,
    ph.PUBLISH_DATE as PUBLISH_DATE,
    buyer.full_name AS FULL_NAME
    FROM 
        pon_auction_headers_all_v ph
    JOIN pon_auction_item_prices_all phl ON ph.AUCTION_HEADER_ID = phl.AUCTION_HEADER_ID
    LEFT JOIN (
        SELECT 
            fu.user_id,
            papf1.full_name
        FROM 
            per_all_people_f papf1
        JOIN fnd_user fu ON papf1.person_id = fu.employee_id
            AND TRUNC(SYSDATE) BETWEEN papf1.EFFECTIVE_START_DATE AND papf1.EFFECTIVE_END_DATE
    ) buyer ON ph.CREATED_BY = buyer.user_id
    JOIN 
        pon_backing_requisitions pbr ON phl.AUCTION_HEADER_ID = pbr.AUCTION_HEADER_ID
        AND phl.LINE_NUMBER = pbr.LINE_NUMBER
    JOIN 
        PO_REQUISITION_HEADERS_ALL prh ON pbr.REQUISITION_HEADER_ID = prh.REQUISITION_HEADER_ID
    JOIN 
        PO_REQUISITION_LINES_ALL prl ON prh.REQUISITION_HEADER_ID = prl.REQUISITION_HEADER_ID
        AND pbr.REQUISITION_LINE_ID = prl.REQUISITION_LINE_ID
    JOIN 
        PO_REQ_DISTRIBUTIONS_ALL prd ON prl.REQUISITION_LINE_ID = prd.REQUISITION_LINE_ID
    WHERE ph.AUCTION_HEADER_ID IN (
        SELECT AUCTION_HEADER_ID
        FROM (
            SELECT AUCTION_HEADER_ID,
                   AUCTION_ROUND_NUMBER,
                   ROW_NUMBER() OVER (PARTITION BY AUCTION_HEADER_ID ORDER BY AUCTION_ROUND_NUMBER DESC) as rn
            FROM pon_auction_headers_all_v
        ) t
        WHERE rn = 1
    )
) AD ON PD.DISTRIBUTION_ID = AD.DISTRIBUTION_ID

LEFT JOIN gl_code_combinations GCC ON PDA.code_combination_id = GCC.code_combination_id
LEFT JOIN wip_entities WE ON PDA.wip_entity_id = WE.wip_entity_id
LEFT JOIN pa_projects_all PPA ON PDA.project_id = PPA.project_id
-- LEFT JOIN xxolng_scm_srn_headers_all SRH ON SRH.po_header_id = PHA.po_header_id AND RSH.attribute1=SRH.SRN_HEADER_ID 
-- AND SRH.PO_RELEASE_ID=PRA.PO_RELEASE_ID
-- LEFT JOIN xxolng_scm_srn_lines_all SRL ON SRL.srn_header_id = SRH.srn_header_id AND PLLA.LINE_LOCATION_ID=SRL.LINE_LOCATION_ID

-- ADDED ALL LINE_TYPE_LOOKUP_CODE INSTEAD OF FIXING FOR LINE TYPE AS ACCRUAL
LEFT JOIN ap_invoice_distributions_all AIDA ON PDA.po_distribution_id = AIDA.po_distribution_id AND NVL(AIDA.CANCELLATION_FLAG, 'Y') = 'N'
LEFT JOIN ap_invoice_lines_all AILA ON AIDA.invoice_id = AILA.invoice_id AND AIDA.invoice_line_number = AILA.line_number AND NVL(AILA.CANCELLED_FLAG,'Y')='N'
LEFT JOIN ap_invoices_all AIA ON AIDA.invoice_id = AIA.invoice_id
LEFT JOIN ap_payment_schedules_all APSA ON AIA.invoice_id = APSA.invoice_id
LEFT JOIN ap_invoice_payments_all AIPA ON AIA.invoice_id = AIPA.invoice_id AND AIPA.PAYMENT_NUM = APSA.PAYMENT_NUM
LEFT JOIN ap_checks_all ACA ON AIPA.check_id = ACA.check_id;