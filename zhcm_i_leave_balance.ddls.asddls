@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface view for Leave Balance'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity zhcm_i_leave_balance as select from pa2006 as LR_B 

inner join pa0105 on LR_B.pernr = pa0105.pernr 
association [0..*] to zhcm_i_leave_balance_it as _Leaves on LR_B.quonr = _Leaves.Quonr
association [1] to zhcm_employee_help as EMP on EMP.pernr = LR_B.pernr
association [1] to zhcm_quotas on zhcm_quotas.Ktart = LR_B.ktart

{
@ObjectModel.text.element: ['ename']
    key LR_B.pernr,
    key LR_B.begda,
    key LR_B.endda,
    @ObjectModel.text.element: ['Ktext']
    @Consumption.valueHelpDefinition: [{ entity: { name : 'zhcm_quotas', element : 'Ktart' } }]
    key LR_B.ktart,
    key LR_B.quonr,
    @Semantics.text: true
    zhcm_quotas.Ktext,
    @Semantics.text: true
    EMP.ename,
    
    LR_B.desta,
    LR_B.deend,
    LR_B.anzhl,
    LR_B.kverb,
    ( LR_B.anzhl - LR_B.kverb ) as rest,
    _Leaves
    
    
} where pa0105.begda <= $session.system_date and pa0105.endda >= $session.system_date and pa0105.usrty = '0001' and pa0105.usrid = $session.user
