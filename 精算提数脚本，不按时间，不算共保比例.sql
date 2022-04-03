SELECT
        b.project_no projectNo, -- 项目号
        b.project_name projectName, -- 项目名称
        c.protocol_number protocolNumber, -- 协议号
        b.pro_start_date proStartDate,  -- 项目起期
        b.pro_end_date proEndDate,  -- 项目终期
        SUBSTR(c.protocol_start_date,1,10) protocolStartDate, -- 协议起期
        SUBSTR(c.protocol_end_date,1,10) protocolEndDate, -- 协议终期
        a.group_policy_num groupPolicyNum,  -- 保单号
       -- a.insurance_code as insuranceCode,  -- 险种代码
        a.responsibility_begin responsibilityBegin, -- 保单责任起期
        a.responsibility_end responsibilityEnd,-- 保单责任终期
        -- d2.branch_id filialeCode, -- 中支公司代码
        -- d1.branch_id branchCode,  -- 分公司代码
        d1.branch branchCodeStr,  -- 分公司名称
        d2.branch filialeCodeStr, -- 中支公司名称
        (CASE WHEN b.is_finished = '1' THEN '是' ELSE '否' END) isFinished, -- 是否结项
        (CASE WHEN c.settlement_flag = '1' THEN '是' ELSE '否' END) settlementFlag, -- 是否协议结算
        c.isshare isshare,   -- 是否共保  0：非共保(独家承保)
       e.divide_percent AS dividePercent, -- （共保比例）
        (CASE WHEN c.isshare = '1' then case when e.divide_type='1'  THEN '是' else '否' end ELSE '_' END) isshareOne , -- 是否主承保
        ifnull(n.total_retention_fee,0)+ifnull(t4.cost4,0)+ifnull(t6.cost6,0)-ifnull(fee.real_reducefee_cost,0) as ysbf,  -- 应收保费（出单保费+加人加费-期末保全-减人减费）
        ifnull(n.total_retention_fee,0) totalCost, --  出单时的总保费（也叫协议保费）
        ifnull(t7.cost7,0) shbf,  -- 缴费金额  （实收保费）
        ifnull(gs5.clmamount,0)-ifnull(ne.clmamoutne, 0) yjpk, --  已决赔款(所有已结案的理赔赔付金额总和（正常理赔+评估费） -  已决的负赔案金额总和+特殊赔案)
        ifnull(gs6.clmamount,0),  -- 已报未决赔款(已复核通过，但未结案)
        ifnull(t1.cost1,0) fxtjjt, -- 风险调节计提(计提金额-红冲金额总和)
        ifnull(t2.cost2,0) yyfh, -- 盈余返还(有保单固定的)
        ifnull(t3.cost3,0) ksmb, -- 亏损弥补
        ifnull(r1.digital_val,0)+ifnull(r3.digital_val,0)+((ifnull(r2.digital_val,0)+ifnull(r4.digital_val,0))/(ifnull(n.total_retention_fee,0)+ifnull(t4.cost4,0)+ifnull(t6.cost6,0)-ifnull(fee.real_reducefee_cost,0))) fyl
        , ifnull(f.pfyg_money,0) zjpfl  -- 赔付预估总额
        FROM group_customer_msg a
        LEFT JOIN project_info b ON a.project_no = b.project_no
        LEFT JOIN protocol_info c ON c.protocol_number = a.protocol_number
        LEFT JOIN protocol_coinsurance e ON e.protocol_id = c.id AND e.insrnc_code = '000015'
        LEFT JOIN dic_branch_mapping d1 ON a.branch_code = d1.branch_id
        LEFT JOIN dic_branch_mapping d2 ON d1.parent_branch_id = d2.branch_id
        LEFT JOIN compensation f ON f.group_policy_number = a.group_policy_num
        LEFT JOIN group_insu_info_input m ON a.id = m.group_customer_id
        LEFT JOIN group_insu_rate_pz n ON n.group_insu_info_input_id = m.id
        LEFT JOIN group_mid_premium_rate r1 ON a.id = r1.group_customer_id AND r1.rate_code='100002'
        LEFT JOIN group_mid_premium_rate r2 ON a.id = r2.group_customer_id AND r2.rate_code='100003'
        LEFT JOIN group_mid_premium_rate r3 ON a.id = r3.group_customer_id AND r3.rate_code='100004'
        LEFT JOIN group_mid_premium_rate r4 ON a.id = r4.group_customer_id AND r4.rate_code='100005'
        LEFT JOIN group_mid_premium_rate r5 ON a.id = r5.group_customer_id AND r5.rate_code='100006'
        LEFT JOIN (
        SELECT
        gg.group_policy_num group_policy_num,
        SUM(c.clmamount) AS clmamount
        FROM subclaimtask sub
        LEFT JOIN claimccl c ON sub.sn = c.sn
        LEFT JOIN group_customer_msg gg ON sub.gpolicyno = gg.group_policy_num
        WHERE sub.status = 2
        and sub.claimtype in ('1','2','4')
        GROUP BY gg.group_policy_num
        ) gs5 ON gs5.group_policy_num = a.group_policy_num

        LEFT JOIN (
        SELECT
        gro.group_policy_num group_policy_num,
        SUM(mccl.clmamount) AS clmamount
        FROM subclaimtask subc
        LEFT JOIN claimccl mccl ON subc.sn = mccl.sn
        LEFT JOIN group_customer_msg gro ON subc.gpolicyno = gro.group_policy_num
        WHERE subc.status = 5
        GROUP BY gro.group_policy_num
        ) gs6 ON gs6.group_policy_num = a.group_policy_num

        LEFT JOIN (
        select nn.group_policy_num group_policy_num, SUM(ifnull(nn.recover_money, 0)) clmamoutne from negative_claim_info nn where
        nn.claim_status='11' and nn.delete_flag = '0'
        GROUP BY nn.group_policy_num
        ) ne ON ne.group_policy_num = a.group_policy_num

        LEFT JOIN
        (SELECT risk.protocol_number protocol_number,SUM(risk.risk_adjust_fund_cost) cost1 FROM risk_adjust_fund risk
        WHERE risk.risk_regulation_type = 'JT1' AND risk.status IN('3','4','5','6','7','8')
        AND risk.delete_flag = '1' GROUP BY risk.protocol_number) t1 ON c.protocol_number = t1.protocol_number

        LEFT JOIN
        (SELECT risk.protocol_number protocol_number,SUM(risk.risk_adjust_fund_cost) cost2 FROM risk_adjust_fund risk
        WHERE risk.risk_regulation_type = 'JT2' AND     risk.status in('3','8')
        AND risk.delete_flag = '1' GROUP BY risk.protocol_number) t2 ON c.protocol_number = t2.protocol_number

        LEFT JOIN
        (SELECT risk.protocol_number protocol_number,SUM(risk.risk_adjust_fund_cost) cost3 FROM risk_adjust_fund risk
        WHERE risk.risk_regulation_type = 'JT3' AND risk.status in('3','8')
        AND risk.delete_flag = '1' GROUP BY risk.protocol_number) t3 ON c.protocol_number = t3.protocol_number

        LEFT JOIN
        (SELECT tpi.policy_no policy_no,SUM(tpi.REAL_ADD_COST) cost4,SUM(tpi.protocol_manage_fund) cost5 FROM
        T_PRESERVE_INFO tpi
        WHERE tpi.PRESERVE_STATUS IN('5','e') AND tpi.delete_flag = '0'
        GROUP BY tpi.policy_no) t4 ON a.group_policy_num
        = t4.policy_no

        LEFT JOIN
        (SELECT tpa.group_policy_num group_policy_num,SUM(tpa.reduce_Cost) cost6 FROM terminal_preserve_apply tpa
        WHERE tpa.PRESERVE_STATUS IN('2') AND tpa.delete_flag = '0'
        GROUP BY tpa.group_policy_num) t6 ON
        a.group_policy_num = t6.group_policy_num

        LEFT JOIN
        (SELECT gpn.group_policy_num group_policy_num,SUM(gpn.curr_payment_money) cost7 FROM group_payment_notice gpn
        WHERE gpn.payment_notice_status IN('3') AND gpn.delete_flag = '0'
        GROUP BY gpn.group_policy_num) t7 ON
        a.group_policy_num = t7.group_policy_num

        -- 查询16减人减费的本次核减应收
        LEFT JOIN (SELECT preserve_status,policy_no,real_reducefee_cost FROM reducefee WHERE 1=1 AND delete_flag = '0'
        AND preserve_status ='6') fee
        ON fee.policy_no = a.group_policy_num

        WHERE a.status_record = '6' AND a.insurance_code ='HT1601' GROUP BY a.group_policy_num
        ;