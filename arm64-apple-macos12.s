    .section __TEXT,__text,regular,pure_instructions
    .private_extern "-[AppDelegate setRunFunction:]"
    .globl "-[AppDelegate setRunFunction:]"
    .p2align 2
"-[AppDelegate setRunFunction:]":
    .cfi_startproc
    cbz x0, LBB0_2
    str x1, [x0, #8]
LBB0_2:
    ret
    .cfi_endproc

    .section __TEXT,__literal8,8byte_literals
    .p2align 3, 0x0
lCPI1_0:
    .long 3254779904
    .long 0
    .section __TEXT,__text,regular,pure_instructions
    .p2align 2
"-[AppDelegate applicationDidFinishLaunching:]":
    .cfi_startproc
    sub sp, sp, #64
    .cfi_def_cfa_offset 64
    stp x29, x30, [sp, #48]
    .cfi_offset w30, -8
    .cfi_offset w29, -16
Lloh0:
    adrp x8, __NSConcreteStackBlock@GOTPAGE
Lloh1:
    ldr x8, [x8, __NSConcreteStackBlock@GOTPAGEOFF]
    str x8, [sp, #8]
Lloh2:
    adrp x8, lCPI1_0@PAGE
Lloh3:
    ldr d0, [x8, lCPI1_0@PAGEOFF]
Lloh4:
    adrp x8, "___45-[AppDelegate applicationDidFinishLaunching:]_block_invoke"@PAGE
Lloh5:
    add x8, x8, "___45-[AppDelegate applicationDidFinishLaunching:]_block_invoke"@PAGEOFF
    str d0, [sp, #16]
Lloh6:
    adrp x9, "___block_descriptor_40_8_32s_e5_v8\x01?0l"@PAGE
Lloh7:
    add x9, x9, "___block_descriptor_40_8_32s_e5_v8\x01?0l"@PAGEOFF
    stp x8, x9, [sp, #24]
    str x0, [sp, #40]
Lloh8:
    adrp x0, __dispatch_main_q@GOTPAGE
Lloh9:
    ldr x0, [x0, __dispatch_main_q@GOTPAGEOFF]
    add x1, sp, #8
    bl _dispatch_async
    ldp x29, x30, [sp, #48]
    add sp, sp, #64
    ret
    .loh AdrpLdrGot Lloh8, Lloh9
    .loh AdrpAdd Lloh6, Lloh7
    .loh AdrpAdd Lloh4, Lloh5
    .loh AdrpAdrp Lloh2, Lloh4
    .loh AdrpLdr Lloh2, Lloh3
    .loh AdrpLdrGot Lloh0, Lloh1
    .cfi_endproc

    .p2align 2
"___45-[AppDelegate applicationDidFinishLaunching:]_block_invoke":
    .cfi_startproc
    ldr x8, [x0, #32]
    ldr x0, [x8, #8]
    cbz x0, LBB2_2
    br x0
LBB2_2:
    ret
    .cfi_endproc

    .private_extern ___copy_helper_block_8_32s
    .globl ___copy_helper_block_8_32s
    .weak_def_can_be_hidden ___copy_helper_block_8_32s
    .p2align 2
___copy_helper_block_8_32s:
    .cfi_startproc
    ldr x0, [x1, #32]
    b _objc_retain
    .cfi_endproc

    .private_extern ___destroy_helper_block_8_32s
    .globl ___destroy_helper_block_8_32s
    .weak_def_can_be_hidden ___destroy_helper_block_8_32s
    .p2align 2
___destroy_helper_block_8_32s:
    .cfi_startproc
    ldr x0, [x0, #32]
    b _objc_release
    .cfi_endproc

    .section __TEXT,__cstring,cstring_literals
l_.str:
    .asciz "v8@?0"

    .private_extern "___block_descriptor_40_8_32s_e5_v8\x01?0l"
    .section __DATA,__const
    .globl "___block_descriptor_40_8_32s_e5_v8\x01?0l"
    .weak_def_can_be_hidden "___block_descriptor_40_8_32s_e5_v8\x01?0l"
    .p2align 3, 0x0
"___block_descriptor_40_8_32s_e5_v8\x01?0l":
    .quad 0
    .quad 40
    .quad ___copy_helper_block_8_32s
    .quad ___destroy_helper_block_8_32s
    .quad l_.str
    .quad 256

    .section __TEXT,__objc_classname,cstring_literals
l_OBJC_CLASS_NAME_:
    .asciz "AppDelegate"

l_OBJC_CLASS_NAME_.1:
    .asciz "NSApplicationDelegate"

l_OBJC_CLASS_NAME_.2:
    .asciz "NSObject"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_:
    .asciz "isEqual:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_:
    .asciz "B24@0:8@16"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.3:
    .asciz "class"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.4:
    .asciz "#16@0:8"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.5:
    .asciz "self"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.6:
    .asciz "@16@0:8"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.7:
    .asciz "performSelector:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.8:
    .asciz "@24@0:8:16"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.9:
    .asciz "performSelector:withObject:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.10:
    .asciz "@32@0:8:16@24"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.11:
    .asciz "performSelector:withObject:withObject:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.12:
    .asciz "@40@0:8:16@24@32"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.13:
    .asciz "isProxy"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.14:
    .asciz "B16@0:8"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.15:
    .asciz "isKindOfClass:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.16:
    .asciz "B24@0:8#16"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.17:
    .asciz "isMemberOfClass:"

l_OBJC_METH_VAR_NAME_.18:
    .asciz "conformsToProtocol:"

l_OBJC_METH_VAR_NAME_.19:
    .asciz "respondsToSelector:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.20:
    .asciz "B24@0:8:16"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.21:
    .asciz "retain"

l_OBJC_METH_VAR_NAME_.22:
    .asciz "release"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.23:
    .asciz "Vv16@0:8"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.24:
    .asciz "autorelease"

l_OBJC_METH_VAR_NAME_.25:
    .asciz "retainCount"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.26:
    .asciz "Q16@0:8"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.27:
    .asciz "zone"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.28:
    .asciz "^{_NSZone=}16@0:8"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.29:
    .asciz "hash"

l_OBJC_METH_VAR_NAME_.30:
    .asciz "superclass"

l_OBJC_METH_VAR_NAME_.31:
    .asciz "description"

    .section __DATA,__objc_const
    .p2align 3, 0x0
__OBJC_$_PROTOCOL_INSTANCE_METHODS_NSObject:
    .long 24
    .long 19
    .quad l_OBJC_METH_VAR_NAME_
    .quad l_OBJC_METH_VAR_TYPE_
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.3
    .quad l_OBJC_METH_VAR_TYPE_.4
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.5
    .quad l_OBJC_METH_VAR_TYPE_.6
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.7
    .quad l_OBJC_METH_VAR_TYPE_.8
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.9
    .quad l_OBJC_METH_VAR_TYPE_.10
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.11
    .quad l_OBJC_METH_VAR_TYPE_.12
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.13
    .quad l_OBJC_METH_VAR_TYPE_.14
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.15
    .quad l_OBJC_METH_VAR_TYPE_.16
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.17
    .quad l_OBJC_METH_VAR_TYPE_.16
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.18
    .quad l_OBJC_METH_VAR_TYPE_
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.19
    .quad l_OBJC_METH_VAR_TYPE_.20
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.21
    .quad l_OBJC_METH_VAR_TYPE_.6
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.22
    .quad l_OBJC_METH_VAR_TYPE_.23
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.24
    .quad l_OBJC_METH_VAR_TYPE_.6
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.25
    .quad l_OBJC_METH_VAR_TYPE_.26
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.27
    .quad l_OBJC_METH_VAR_TYPE_.28
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.29
    .quad l_OBJC_METH_VAR_TYPE_.26
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.30
    .quad l_OBJC_METH_VAR_TYPE_.4
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.31
    .quad l_OBJC_METH_VAR_TYPE_.6
    .quad 0

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.32:
    .asciz "debugDescription"

    .section __DATA,__objc_const
    .p2align 3, 0x0
__OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSObject:
    .long 24
    .long 1
    .quad l_OBJC_METH_VAR_NAME_.32
    .quad l_OBJC_METH_VAR_TYPE_.6
    .quad 0

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_PROP_NAME_ATTR_:
    .asciz "hash"

l_OBJC_PROP_NAME_ATTR_.33:
    .asciz "TQ,R"

l_OBJC_PROP_NAME_ATTR_.34:
    .asciz "superclass"

l_OBJC_PROP_NAME_ATTR_.35:
    .asciz "T#,R"

l_OBJC_PROP_NAME_ATTR_.36:
    .asciz "description"

l_OBJC_PROP_NAME_ATTR_.37:
    .asciz "T@\"NSString\",R,C"

l_OBJC_PROP_NAME_ATTR_.38:
    .asciz "debugDescription"

l_OBJC_PROP_NAME_ATTR_.39:
    .asciz "T@\"NSString\",?,R,C"

    .section __DATA,__objc_const
    .p2align 3, 0x0
__OBJC_$_PROP_LIST_NSObject:
    .long 16
    .long 4
    .quad l_OBJC_PROP_NAME_ATTR_
    .quad l_OBJC_PROP_NAME_ATTR_.33
    .quad l_OBJC_PROP_NAME_ATTR_.34
    .quad l_OBJC_PROP_NAME_ATTR_.35
    .quad l_OBJC_PROP_NAME_ATTR_.36
    .quad l_OBJC_PROP_NAME_ATTR_.37
    .quad l_OBJC_PROP_NAME_ATTR_.38
    .quad l_OBJC_PROP_NAME_ATTR_.39

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.40:
    .asciz "B24@0:8@\"Protocol\"16"

l_OBJC_METH_VAR_TYPE_.41:
    .asciz "@\"NSString\"16@0:8"

    .section __DATA,__objc_const
    .p2align 3, 0x0
__OBJC_$_PROTOCOL_METHOD_TYPES_NSObject:
    .quad l_OBJC_METH_VAR_TYPE_
    .quad l_OBJC_METH_VAR_TYPE_.4
    .quad l_OBJC_METH_VAR_TYPE_.6
    .quad l_OBJC_METH_VAR_TYPE_.8
    .quad l_OBJC_METH_VAR_TYPE_.10
    .quad l_OBJC_METH_VAR_TYPE_.12
    .quad l_OBJC_METH_VAR_TYPE_.14
    .quad l_OBJC_METH_VAR_TYPE_.16
    .quad l_OBJC_METH_VAR_TYPE_.16
    .quad l_OBJC_METH_VAR_TYPE_.40
    .quad l_OBJC_METH_VAR_TYPE_.20
    .quad l_OBJC_METH_VAR_TYPE_.6
    .quad l_OBJC_METH_VAR_TYPE_.23
    .quad l_OBJC_METH_VAR_TYPE_.6
    .quad l_OBJC_METH_VAR_TYPE_.26
    .quad l_OBJC_METH_VAR_TYPE_.28
    .quad l_OBJC_METH_VAR_TYPE_.26
    .quad l_OBJC_METH_VAR_TYPE_.4
    .quad l_OBJC_METH_VAR_TYPE_.41
    .quad l_OBJC_METH_VAR_TYPE_.41

    .private_extern __OBJC_PROTOCOL_$_NSObject
    .section __DATA,__data
    .globl __OBJC_PROTOCOL_$_NSObject
    .weak_definition __OBJC_PROTOCOL_$_NSObject
    .p2align 3, 0x0
__OBJC_PROTOCOL_$_NSObject:
    .quad 0
    .quad l_OBJC_CLASS_NAME_.2
    .quad 0
    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_NSObject
    .quad 0
    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSObject
    .quad 0
    .quad __OBJC_$_PROP_LIST_NSObject
    .long 96
    .long 0
    .quad __OBJC_$_PROTOCOL_METHOD_TYPES_NSObject
    .quad 0
    .quad 0

    .private_extern __OBJC_LABEL_PROTOCOL_$_NSObject
    .section __DATA,__objc_protolist,coalesced,no_dead_strip
    .globl __OBJC_LABEL_PROTOCOL_$_NSObject
    .weak_definition __OBJC_LABEL_PROTOCOL_$_NSObject
    .p2align 3, 0x0
__OBJC_LABEL_PROTOCOL_$_NSObject:
    .quad __OBJC_PROTOCOL_$_NSObject

    .section __DATA,__objc_const
    .p2align 3, 0x0
__OBJC_$_PROTOCOL_REFS_NSApplicationDelegate:
    .quad 1
    .quad __OBJC_PROTOCOL_$_NSObject
    .quad 0

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.42:
    .asciz "applicationShouldTerminate:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.43:
    .asciz "Q24@0:8@16"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.44:
    .asciz "application:openURLs:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.45:
    .asciz "v32@0:8@16@24"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.46:
    .asciz "application:openFile:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.47:
    .asciz "B32@0:8@16@24"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.48:
    .asciz "application:openFiles:"

l_OBJC_METH_VAR_NAME_.49:
    .asciz "application:openTempFile:"

l_OBJC_METH_VAR_NAME_.50:
    .asciz "applicationShouldOpenUntitledFile:"

l_OBJC_METH_VAR_NAME_.51:
    .asciz "applicationOpenUntitledFile:"

l_OBJC_METH_VAR_NAME_.52:
    .asciz "application:openFileWithoutUI:"

l_OBJC_METH_VAR_NAME_.53:
    .asciz "application:printFile:"

l_OBJC_METH_VAR_NAME_.54:
    .asciz "application:printFiles:withSettings:showPrintPanels:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.55:
    .asciz "Q44@0:8@16@24@32B40"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.56:
    .asciz "applicationShouldTerminateAfterLastWindowClosed:"

l_OBJC_METH_VAR_NAME_.57:
    .asciz "applicationShouldHandleReopen:hasVisibleWindows:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.58:
    .asciz "B28@0:8@16B24"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.59:
    .asciz "applicationDockMenu:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.60:
    .asciz "@24@0:8@16"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.61:
    .asciz "application:willPresentError:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.62:
    .asciz "@32@0:8@16@24"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.63:
    .asciz "application:didRegisterForRemoteNotificationsWithDeviceToken:"

l_OBJC_METH_VAR_NAME_.64:
    .asciz "application:didFailToRegisterForRemoteNotificationsWithError:"

l_OBJC_METH_VAR_NAME_.65:
    .asciz "application:didReceiveRemoteNotification:"

l_OBJC_METH_VAR_NAME_.66:
    .asciz "applicationSupportsSecureRestorableState:"

l_OBJC_METH_VAR_NAME_.67:
    .asciz "application:handlerForIntent:"

l_OBJC_METH_VAR_NAME_.68:
    .asciz "application:willEncodeRestorableState:"

l_OBJC_METH_VAR_NAME_.69:
    .asciz "application:didDecodeRestorableState:"

l_OBJC_METH_VAR_NAME_.70:
    .asciz "application:willContinueUserActivityWithType:"

l_OBJC_METH_VAR_NAME_.71:
    .asciz "application:continueUserActivity:restorationHandler:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.72:
    .asciz "B40@0:8@16@24@?32"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.73:
    .asciz "application:didFailToContinueUserActivityWithType:error:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.74:
    .asciz "v40@0:8@16@24@32"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.75:
    .asciz "application:didUpdateUserActivity:"

l_OBJC_METH_VAR_NAME_.76:
    .asciz "application:userDidAcceptCloudKitShareWithMetadata:"

l_OBJC_METH_VAR_NAME_.77:
    .asciz "application:delegateHandlesKey:"

l_OBJC_METH_VAR_NAME_.78:
    .asciz "applicationShouldAutomaticallyLocalizeKeyEquivalents:"

l_OBJC_METH_VAR_NAME_.79:
    .asciz "applicationWillFinishLaunching:"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.80:
    .asciz "v24@0:8@16"

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.81:
    .asciz "applicationDidFinishLaunching:"

l_OBJC_METH_VAR_NAME_.82:
    .asciz "applicationWillHide:"

l_OBJC_METH_VAR_NAME_.83:
    .asciz "applicationDidHide:"

l_OBJC_METH_VAR_NAME_.84:
    .asciz "applicationWillUnhide:"

l_OBJC_METH_VAR_NAME_.85:
    .asciz "applicationDidUnhide:"

l_OBJC_METH_VAR_NAME_.86:
    .asciz "applicationWillBecomeActive:"

l_OBJC_METH_VAR_NAME_.87:
    .asciz "applicationDidBecomeActive:"

l_OBJC_METH_VAR_NAME_.88:
    .asciz "applicationWillResignActive:"

l_OBJC_METH_VAR_NAME_.89:
    .asciz "applicationDidResignActive:"

l_OBJC_METH_VAR_NAME_.90:
    .asciz "applicationWillUpdate:"

l_OBJC_METH_VAR_NAME_.91:
    .asciz "applicationDidUpdate:"

l_OBJC_METH_VAR_NAME_.92:
    .asciz "applicationWillTerminate:"

l_OBJC_METH_VAR_NAME_.93:
    .asciz "applicationDidChangeScreenParameters:"

l_OBJC_METH_VAR_NAME_.94:
    .asciz "applicationDidChangeOcclusionState:"

l_OBJC_METH_VAR_NAME_.95:
    .asciz "applicationProtectedDataWillBecomeUnavailable:"

l_OBJC_METH_VAR_NAME_.96:
    .asciz "applicationProtectedDataDidBecomeAvailable:"

    .section __DATA,__objc_const
    .p2align 3, 0x0
__OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSApplicationDelegate:
    .long 24
    .long 45
    .quad l_OBJC_METH_VAR_NAME_.42
    .quad l_OBJC_METH_VAR_TYPE_.43
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.44
    .quad l_OBJC_METH_VAR_TYPE_.45
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.46
    .quad l_OBJC_METH_VAR_TYPE_.47
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.48
    .quad l_OBJC_METH_VAR_TYPE_.45
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.49
    .quad l_OBJC_METH_VAR_TYPE_.47
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.50
    .quad l_OBJC_METH_VAR_TYPE_
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.51
    .quad l_OBJC_METH_VAR_TYPE_
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.52
    .quad l_OBJC_METH_VAR_TYPE_.47
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.53
    .quad l_OBJC_METH_VAR_TYPE_.47
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.54
    .quad l_OBJC_METH_VAR_TYPE_.55
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.56
    .quad l_OBJC_METH_VAR_TYPE_
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.57
    .quad l_OBJC_METH_VAR_TYPE_.58
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.59
    .quad l_OBJC_METH_VAR_TYPE_.60
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.61
    .quad l_OBJC_METH_VAR_TYPE_.62
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.63
    .quad l_OBJC_METH_VAR_TYPE_.45
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.64
    .quad l_OBJC_METH_VAR_TYPE_.45
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.65
    .quad l_OBJC_METH_VAR_TYPE_.45
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.66
    .quad l_OBJC_METH_VAR_TYPE_
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.67
    .quad l_OBJC_METH_VAR_TYPE_.62
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.68
    .quad l_OBJC_METH_VAR_TYPE_.45
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.69
    .quad l_OBJC_METH_VAR_TYPE_.45
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.70
    .quad l_OBJC_METH_VAR_TYPE_.47
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.71
    .quad l_OBJC_METH_VAR_TYPE_.72
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.73
    .quad l_OBJC_METH_VAR_TYPE_.74
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.75
    .quad l_OBJC_METH_VAR_TYPE_.45
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.76
    .quad l_OBJC_METH_VAR_TYPE_.45
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.77
    .quad l_OBJC_METH_VAR_TYPE_.47
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.78
    .quad l_OBJC_METH_VAR_TYPE_
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.79
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.81
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.82
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.83
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.84
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.85
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.86
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.87
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.88
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.89
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.90
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.91
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.92
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.93
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.94
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.95
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0
    .quad l_OBJC_METH_VAR_NAME_.96
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad 0

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.97:
    .asciz "Q24@0:8@\"NSApplication\"16"

l_OBJC_METH_VAR_TYPE_.98:
    .asciz "v32@0:8@\"NSApplication\"16@\"NSArray\"24"

l_OBJC_METH_VAR_TYPE_.99:
    .asciz "B32@0:8@\"NSApplication\"16@\"NSString\"24"

l_OBJC_METH_VAR_TYPE_.100:
    .asciz "B24@0:8@\"NSApplication\"16"

l_OBJC_METH_VAR_TYPE_.101:
    .asciz "B32@0:8@16@\"NSString\"24"

l_OBJC_METH_VAR_TYPE_.102:
    .asciz "Q44@0:8@\"NSApplication\"16@\"NSArray\"24@\"NSDictionary\"32B40"

l_OBJC_METH_VAR_TYPE_.103:
    .asciz "B28@0:8@\"NSApplication\"16B24"

l_OBJC_METH_VAR_TYPE_.104:
    .asciz "@\"NSMenu\"24@0:8@\"NSApplication\"16"

l_OBJC_METH_VAR_TYPE_.105:
    .asciz "@\"NSError\"32@0:8@\"NSApplication\"16@\"NSError\"24"

l_OBJC_METH_VAR_TYPE_.106:
    .asciz "v32@0:8@\"NSApplication\"16@\"NSData\"24"

l_OBJC_METH_VAR_TYPE_.107:
    .asciz "v32@0:8@\"NSApplication\"16@\"NSError\"24"

l_OBJC_METH_VAR_TYPE_.108:
    .asciz "v32@0:8@\"NSApplication\"16@\"NSDictionary\"24"

l_OBJC_METH_VAR_TYPE_.109:
    .asciz "@32@0:8@\"NSApplication\"16@\"INIntent\"24"

l_OBJC_METH_VAR_TYPE_.110:
    .asciz "v32@0:8@\"NSApplication\"16@\"NSCoder\"24"

l_OBJC_METH_VAR_TYPE_.111:
    .asciz "B40@0:8@\"NSApplication\"16@\"NSUserActivity\"24@?<v@?@\"NSArray\">32"

l_OBJC_METH_VAR_TYPE_.112:
    .asciz "v40@0:8@\"NSApplication\"16@\"NSString\"24@\"NSError\"32"

l_OBJC_METH_VAR_TYPE_.113:
    .asciz "v32@0:8@\"NSApplication\"16@\"NSUserActivity\"24"

l_OBJC_METH_VAR_TYPE_.114:
    .asciz "v32@0:8@\"NSApplication\"16@\"CKShareMetadata\"24"

l_OBJC_METH_VAR_TYPE_.115:
    .asciz "v24@0:8@\"NSNotification\"16"

    .section __DATA,__objc_const
    .p2align 3, 0x0
__OBJC_$_PROTOCOL_METHOD_TYPES_NSApplicationDelegate:
    .quad l_OBJC_METH_VAR_TYPE_.97
    .quad l_OBJC_METH_VAR_TYPE_.98
    .quad l_OBJC_METH_VAR_TYPE_.99
    .quad l_OBJC_METH_VAR_TYPE_.98
    .quad l_OBJC_METH_VAR_TYPE_.99
    .quad l_OBJC_METH_VAR_TYPE_.100
    .quad l_OBJC_METH_VAR_TYPE_.100
    .quad l_OBJC_METH_VAR_TYPE_.101
    .quad l_OBJC_METH_VAR_TYPE_.99
    .quad l_OBJC_METH_VAR_TYPE_.102
    .quad l_OBJC_METH_VAR_TYPE_.100
    .quad l_OBJC_METH_VAR_TYPE_.103
    .quad l_OBJC_METH_VAR_TYPE_.104
    .quad l_OBJC_METH_VAR_TYPE_.105
    .quad l_OBJC_METH_VAR_TYPE_.106
    .quad l_OBJC_METH_VAR_TYPE_.107
    .quad l_OBJC_METH_VAR_TYPE_.108
    .quad l_OBJC_METH_VAR_TYPE_.100
    .quad l_OBJC_METH_VAR_TYPE_.109
    .quad l_OBJC_METH_VAR_TYPE_.110
    .quad l_OBJC_METH_VAR_TYPE_.110
    .quad l_OBJC_METH_VAR_TYPE_.99
    .quad l_OBJC_METH_VAR_TYPE_.111
    .quad l_OBJC_METH_VAR_TYPE_.112
    .quad l_OBJC_METH_VAR_TYPE_.113
    .quad l_OBJC_METH_VAR_TYPE_.114
    .quad l_OBJC_METH_VAR_TYPE_.99
    .quad l_OBJC_METH_VAR_TYPE_.100
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115
    .quad l_OBJC_METH_VAR_TYPE_.115

    .private_extern __OBJC_PROTOCOL_$_NSApplicationDelegate
    .section __DATA,__data
    .globl __OBJC_PROTOCOL_$_NSApplicationDelegate
    .weak_definition __OBJC_PROTOCOL_$_NSApplicationDelegate
    .p2align 3, 0x0
__OBJC_PROTOCOL_$_NSApplicationDelegate:
    .quad 0
    .quad l_OBJC_CLASS_NAME_.1
    .quad __OBJC_$_PROTOCOL_REFS_NSApplicationDelegate
    .quad 0
    .quad 0
    .quad __OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_NSApplicationDelegate
    .quad 0
    .quad 0
    .long 96
    .long 0
    .quad __OBJC_$_PROTOCOL_METHOD_TYPES_NSApplicationDelegate
    .quad 0
    .quad 0

    .private_extern __OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate
    .section __DATA,__objc_protolist,coalesced,no_dead_strip
    .globl __OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate
    .weak_definition __OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate
    .p2align 3, 0x0
__OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate:
    .quad __OBJC_PROTOCOL_$_NSApplicationDelegate

    .section __DATA,__objc_const
    .p2align 3, 0x0
__OBJC_CLASS_PROTOCOLS_$_AppDelegate:
    .quad 1
    .quad __OBJC_PROTOCOL_$_NSApplicationDelegate
    .quad 0

    .p2align 3, 0x0
__OBJC_METACLASS_RO_$_AppDelegate:
    .long 129
    .long 40
    .long 40
    .space 4
    .quad 0
    .quad l_OBJC_CLASS_NAME_
    .quad 0
    .quad __OBJC_CLASS_PROTOCOLS_$_AppDelegate
    .quad 0
    .quad 0
    .quad 0

    .section __DATA,__objc_data
    .globl _OBJC_METACLASS_$_AppDelegate
    .p2align 3, 0x0
_OBJC_METACLASS_$_AppDelegate:
    .quad _OBJC_METACLASS_$_NSObject
    .quad _OBJC_METACLASS_$_NSObject
    .quad __objc_empty_cache
    .quad 0
    .quad __OBJC_METACLASS_RO_$_AppDelegate

    .section __DATA,__objc_const
    .p2align 3, 0x0
__OBJC_$_INSTANCE_METHODS_AppDelegate:
    .long 24
    .long 1
    .quad l_OBJC_METH_VAR_NAME_.81
    .quad l_OBJC_METH_VAR_TYPE_.80
    .quad "-[AppDelegate applicationDidFinishLaunching:]"

    .private_extern _OBJC_IVAR_$_AppDelegate._runFunction
    .section __DATA,__objc_ivar
    .globl _OBJC_IVAR_$_AppDelegate._runFunction
    .p2align 2, 0x0
_OBJC_IVAR_$_AppDelegate._runFunction:
    .long 8

    .section __TEXT,__objc_methname,cstring_literals
l_OBJC_METH_VAR_NAME_.116:
    .asciz "_runFunction"

    .section __TEXT,__objc_methtype,cstring_literals
l_OBJC_METH_VAR_TYPE_.117:
    .asciz "^?"

    .section __DATA,__objc_const
    .p2align 3, 0x0
__OBJC_$_INSTANCE_VARIABLES_AppDelegate:
    .long 32
    .long 1
    .quad _OBJC_IVAR_$_AppDelegate._runFunction
    .quad l_OBJC_METH_VAR_NAME_.116
    .quad l_OBJC_METH_VAR_TYPE_.117
    .long 3
    .long 8

    .p2align 3, 0x0
__OBJC_$_PROP_LIST_AppDelegate:
    .long 16
    .long 4
    .quad l_OBJC_PROP_NAME_ATTR_
    .quad l_OBJC_PROP_NAME_ATTR_.33
    .quad l_OBJC_PROP_NAME_ATTR_.34
    .quad l_OBJC_PROP_NAME_ATTR_.35
    .quad l_OBJC_PROP_NAME_ATTR_.36
    .quad l_OBJC_PROP_NAME_ATTR_.37
    .quad l_OBJC_PROP_NAME_ATTR_.38
    .quad l_OBJC_PROP_NAME_ATTR_.39

    .p2align 3, 0x0
__OBJC_CLASS_RO_$_AppDelegate:
    .long 128
    .long 8
    .long 16
    .space 4
    .quad 0
    .quad l_OBJC_CLASS_NAME_
    .quad __OBJC_$_INSTANCE_METHODS_AppDelegate
    .quad __OBJC_CLASS_PROTOCOLS_$_AppDelegate
    .quad __OBJC_$_INSTANCE_VARIABLES_AppDelegate
    .quad 0
    .quad __OBJC_$_PROP_LIST_AppDelegate

    .section __DATA,__objc_data
    .globl _OBJC_CLASS_$_AppDelegate
    .p2align 3, 0x0
_OBJC_CLASS_$_AppDelegate:
    .quad _OBJC_METACLASS_$_AppDelegate
    .quad _OBJC_CLASS_$_NSObject
    .quad __objc_empty_cache
    .quad 0
    .quad __OBJC_CLASS_RO_$_AppDelegate

    .section __DATA,__objc_classlist,regular,no_dead_strip
    .p2align 3, 0x0
l_OBJC_LABEL_CLASS_$:
    .quad _OBJC_CLASS_$_AppDelegate

    .no_dead_strip __OBJC_LABEL_PROTOCOL_$_NSApplicationDelegate
    .no_dead_strip __OBJC_LABEL_PROTOCOL_$_NSObject
    .no_dead_strip __OBJC_PROTOCOL_$_NSApplicationDelegate
    .no_dead_strip __OBJC_PROTOCOL_$_NSObject
    .section __DATA,__objc_imageinfo,regular,no_dead_strip
L_OBJC_IMAGE_INFO:
    .long 0
    .long 64

.subsections_via_symbols
