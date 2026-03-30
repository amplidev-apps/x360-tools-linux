var count;
var order = "Name";
var filter = "none";
var title = {
    Page: 0,
    Total: 0,
    Pages: 1,
    Increment: 10,
    Sort: 3,
    SortDirection: 1,
    Category: 0,
    Filter: 0
};
var approve = {
    Index: 0,
    List: [],
    Step: 10,
    Total: 0,
    Page: 0,
    Pages: 0
};
var uploadID = "";
var uploadType = 1;
var uploadTerm = "";
var loginBox = "";
var maxPassCode = 4;
var LinkIndex = 0;
var opts = {
    lines: 15,
    length: 30,
    width: 10,
    radius: 35,
    corners: 1,
    rotate: 0,
    direction: 1,
    color: "#fff",
    speed: 1.3,
    trail: 100,
    shadow: true,
    hwaccel: true,
    className: "spinner",
    zIndex: 2000000000,
    top: "150px",
    left: "auto"
};
var RegPass = {
    Username: false,
    Password: false,
    Fullname: false,
    Email: false,
	Captcha: false
};
var adminSearch = "";
var adminPage = 0;
var adminTotal = 0;
var adminPages = 1;
var adminIncrement = 50;
var me = new Array();
me.Level = 0;
var approveString = "";
var searchString = "";
$(document).ready(function() {
    if ($(window).width() < 1550) {
        $("#RightAd").hide()
    }
    if ($(window).width() < 1200) {
        $("#LeftAd").hide()
    }
    $(window).resize(function() {
        if ($(window).width() < 1550) {
            $("#RightAd").hide()
        } else {
            $("#RightAd").show()
        }
        if ($(window).width() < 1200) {
            $("#LeftAd").hide()
        } else {
            $("#LeftAd").show()
        }
    });
    loginBox = $("#LoginPanel").html();
    $(document).tooltip();
    $("#dialog-positive").dialog({
        modal: true,
        autoOpen: false,
        buttons: {
            Ok: function() {
                $(this).dialog("close")
            }
        }
    });
    $("#dialog-negative").dialog({
        modal: true,
        autoOpen: false,
        buttons: {
            Ok: function() {
                $(this).dialog("close")
            }
        }
    });
    var a = document.getElementById("MainContent");
    var b = new Spinner(opts).spin(a);
    $("#home").click(function() {
        searchString = "";
        $("#searchtext").val("");
        titlePage = 0;
        getTitleList(true)
    });
    setInterval(function() {
        getMe(false)
    }, 900000);
    if ($("#activecode").val() == "no") {
        getMe(false)
    } else {
        var d = $("#activecode").val();
        var c = $("#activeuser").val();
        $.ajax({
            url: "Resources/Lib/ActivateProcess.php",
            type: "GET",
            data: {
                code: d,
                user: c
            },
            dataType: "json",
            success: function(e) {
                d = "";
                var f = e;
                $.ajax({
                    url: "/Resources/Template/Activate.html",
                    type: "GET",
                    data: {},
                    dataType: "text",
                    success: function(g) {
                        $("#PaneTitle").html("Activation");
                        $(".MainContent").setTemplate(g);
                        $(".MainContent").processTemplate(f);
                        $("#ResendActivation").click(function() {
                            $.ajax({
                                url: "Resources/Lib/ResendActivation.php",
                                type: "GET",
                                data: {
                                    user: c
                                },
                                dataType: "json",
                                success: function(h) {
                                    $("#ActivationInfo").html("<p class='PageInfo'>Activation Email Resent to your registered email address.</p>")
                                }
                            })
                        })
                    }
                })
            }
        })
    }
    getTitleList(true);
    $("#Login").click(function() {
        $("#LoginPanel").html(loginBox);
        if ($("#LoginPanel").css("display") == "none") {
            $("#LoginPanel").show("slide", {
                direction: "up"
            }, 400, function() {
                $("#username").focus();
                $("#LoginButton").click(function() {
                    getMe(true)
                });
                $("#password").keypress(function(e) {
                    if (e.which == 13) {
                        event.preventDefault();
                        getMe(true)
                    }
                })
            })
        } else {
            $("#LoginPanel").hide("slide", {
                direction: "up"
            });
            $("#LoginPanel").html("")
        }
    });
    $("#Register").click(function() {
        var e = document.getElementById("MainContent");
        var f = new Spinner(opts).spin(e);
        $.ajax({
            url: "Resources/Template/Register.html",
            type: "GET",
            data: {},
            dataType: "text",
            success: function(g) {
                $("#PaneTitle").html("Registration");
                $(".MainContent").setTemplate(g);
                $(".MainContent").processTemplate();
                $("#Registrationusername").keyup(function() {
                    var h = this;
                    if (this.timer) {
                        clearTimeout(this.timer)
                    }
                    if ($("#Registrationusername").val().length <= 0) {
                        RegPass.Username = false;
                        return
                    }
                    this.timer = setTimeout(function() {
                        if ($("#Registrationusername").val().length < 3) {
                            $("#Registrationusername").addClass("Invalid");
                            $("#Registrationusername").removeClass("Valid");
                            $("#response").html("Username must be more than 3 Characters");
                            RegPass.Username = false
                        } else {
                            $.ajax({
                                url: "Resources/Lib/ValidateUser.php",
                                type: "GET",
                                data: {
                                    uname: $("#Registrationusername").val()
                                },
                                dataType: "json",
                                success: function(i) {
                                    if (i.Result) {
                                        $("#Registrationusername").addClass("Valid");
                                        $("#Registrationusername").removeClass("Invalid");
                                        $("#response").html("");
                                        RegPass.Username = true
                                    } else {
                                        $("#Registrationusername").removeClass("Valid");
                                        $("#Registrationusername").addClass("Invalid");
                                        $("#response").html("Username Already Taken");
                                        RegPass.Username = false
                                    }
                                }
                            })
                        }
                    }, 0)
                });
                $("#Registrationemail").keyup(function() {
                    var h = this;
                    if (this.timer) {
                        clearTimeout(this.timer)
                    }
                    if ($("#Registrationemail").val().length <= 0) {
                        RegPass.Email = false;
                        return
                    }
                    this.timer = setTimeout(function() {
                        var i = /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,6}$/i;
                        if (!i.test($("#Registrationemail").val())) {
                            $("#Registrationemail").addClass("Invalid");
                            $("#Registrationemail").removeClass("Valid");
                            $("#response").html("Invalid email address format");
                            RegPass.Email = false
                        } else {
                            $.ajax({
                                url: "Resources/Lib/ValidateEmail.php",
                                type: "GET",
                                data: {
                                    email: $("#Registrationemail").val()
                                },
                                dataType: "json",
                                success: function(j) {
                                    if (j.Result) {
                                        $("#Registrationemail").addClass("Valid");
                                        $("#Registrationemail").removeClass("Invalid");
                                        $("#response").html("");
                                        RegPass.Email = true
                                    } else {
                                        $("#Registrationemail").removeClass("Valid");
                                        $("#Registrationemail").addClass("Invalid");
                                        $("#response").html("Email Already Registered");
                                        RegPass.Email = false
                                    }
                                }
                            })
                        }
                    }, 500)
                });
                $("#pwd").keyup(function() {
                    var h = this;
                    if (this.timer) {
                        clearTimeout(this.timer)
                    }
                    if ($("#pwd").val().length <= 0) {
                        RegPass.Password = false;
                        return
                    }
                    this.timer = setTimeout(function() {
                        if ($("#pwd").val().length < 8) {
                            $("#pwd").addClass("Invalid");
                            $("#pwd").removeClass("Valid");
                            $("#response").html("Password must be 8 Characters.");
                            RegPass.Password = false
                        } else {
                            if ($("#pwd").val() != $("#pwd2").val() && $("#pwd2").val().length >= 8) {
                                $("#pwd").addClass("Invalid");
                                $("#pwd2").addClass("Invalid");
                                $("#pwd").removeClass("Valid");
                                $("#pwd2").removeClass("Valid");
                                $("#response").html("Password Don't match");
                                RegPass.Password = false
                            } else {
                                $("#pwd").addClass("Valid");
                                $("#pwd2").addClass("Valid");
                                $("#pwd").removeClass("Invalid");
                                $("#pwd2").removeClass("Invalid");
                                $("#response").html("");
                                RegPass.Password = true
                            }
                        }
                    }, 500)
                });
                $("#pwd2").keyup(function() {
                    var h = this;
                    if (this.timer) {
                        clearTimeout(this.timer)
                    }
                    if ($("#pwd2").val().length <= 0) {
                        RegPass.Password = false;
                        return
                    }
                    this.timer = setTimeout(function() {
                        if ($("#pwd2").val().length < 8) {
                            $("#pwd2").addClass("Invalid");
                            $("#pwd2").removeClass("Valid");
                            $("#response").html("Password must be 8 Characters.");
                            RegPass.Password = false
                        } else {
                            if ($("#pwd").val() != $("#pwd2").val() && $("#pwd").val().length >= 8) {
                                $("#pwd").addClass("Invalid");
                                $("#pwd2").addClass("Invalid");
                                $("#pwd").removeClass("Valid");
                                $("#pwd2").removeClass("Valid");
                                $("#response").html("Password Don't match");
                                RegPass.Password = false
                            } else {
                                $("#pwd").addClass("Valid");
                                $("#pwd2").addClass("Valid");
                                $("#pwd").removeClass("Invalid");
                                $("#pwd2").removeClass("Invalid");
                                $("#response").html("");
                                RegPass.Password = true
                            }
                        }
                    }, 0)
                });
				/*
	function checkForm(form) {
	if(!form.captcha.value.match(/^\d{5}$/)) {
		alert('Enter the CAPTCHA digits in the box provided');
		form.captcha.focus();
		return false;
	}

	return true;
	}
				*/
                $("#RegistrationFullName").keyup(function() {
                    var h = this;
                    if (this.timer) {
                        clearTimeout(this.timer)
                    }
                    if ($("#RegistrationFullName").val().length <= 0) {
                        RegPass.Fullname = false;
                        return
                    }
                    this.timer = setTimeout(function() {
                        if ($("#RegistrationFullName").val().length < 3) {
                            $("#RegistrationFullName").addClass("Invalid");
                            $("#RegistrationFullName").removeClass("Valid");
                            $("#response").html("Full name must be at least 3 characters.");
                            RegPass.Fullname = false
                        } else {
                            $("#RegistrationFullName").addClass("Valid");
                            $("#RegistrationFullName").removeClass("Invalid");
                            $("#response").html("");
                            RegPass.Fullname = true
                        }
                    }, 500)
                });
                $("#Registrationcaptcha").keyup(function() {
                    var h = this;
                    if (this.timer) {
                        clearTimeout(this.timer)
                    }
                    if ($("#Registrationcaptcha").val().length <= 0) {
                        RegPass.Captcha = false;
                        return
                    }
                    this.timer = setTimeout(function() {
                        if ($("#Registrationcaptcha").val().length != 5) {
                            $("#Registrationcaptcha").addClass("Invalid");
                            $("#Registrationcaptcha").removeClass("Valid");
                            $("#response").html("Invalid captcha");
                            RegPass.Captcha = false
                        } else {
                            $("#Registrationcaptcha").addClass("Valid");
                            $("#Registrationcaptcha").removeClass("Invalid");
                            $("#response").html("");
                            RegPass.Captcha = true
                        }
                    }, 500)
                });
                $("#RegistrationSubmit").click(function() {
                    if (RegPass.Fullname && RegPass.Username && RegPass.Email && RegPass.Password && RegPass.Captcha) {
                        $.ajax({
                            url: "Resources/Lib/Register.php",
                            type: "GET",
                            data: {
                                username: $("#Registrationusername").val(),
                                email: $("#Registrationemail").val(),
                                fullname: $("#RegistrationFullName").val(),
                                password: $("#pwd").val(),
                                captcha: $("#Registrationcaptcha").val(),
                            },
                            dataType: "json",
                            success: function(h) {
                                if (h.Error) {
                                    $("#response").html(h.Error)
                                } else {
                                    $("#response").html(h.Success)
                                }
                            }
                        })
                    } else {
                        $("#response").html("Please correct fields marked in RED or empty")
                    }
                })
            },
            error: function(g) {}
        })
    });
    $(document).mousedown(function(e) {
        if (!$("#LoginPanel").is(e.target) && $("#LoginPanel").has(e.target).length === 0) {
            $("#LoginPanel").hide("slide", {
                direction: "up"
            }, 400);
            $("#LoginPanel").html("")
        }
    });
    $("#NavTitleList").click(function() {
        getTitleList(true)
    });
    $("#NavRecentList").click(function() {
        searchString = "";
        $("#searchBox").val("");
        titlePage = 0;
        getTitleList(true)
    });
    $("#UserDropdown").jui_dropdown({
        launcher_id: "User",
        launcher_container_id: "UserButtonContainer",
        menu_id: "UserMenu",
        containerClass: "ContainerClass",
        menuClass: "MenuClass",
        launcher_is_UI_button: false,
        onSelect: function(f, j) {
            if (j.id == "Logout") {
                $.ajax({
                    url: "Resources/Lib/logout.php",
                    type: "GET",
                    data: {},
                    dataType: "json",
                    success: function(n) {
                        if (n.Error) {} else {
                            me = new Array();
                            me.Level = 0;
                            $("#User").html("");
                            $("#Login").show();
                            $("#LoginOr").show();
                            $("#Register").show();
                            $("#User").hide();
                            searchString = "";
                            $("#searchBox").val("");
                            titlePage = 0;
                            getTitleList(true)
                        }
                    }
                })
            } else {
                if (j.id == "Friends") {
                    var l = document.getElementById("MainContent");
                    var m = new Spinner(opts).spin(l);
                    var k = $.createTemplateURL("/Resources/Template/FriendList.html");
                    $(".MainContent").html($.processTemplateToText(k));
                    var i = $.createTemplateURL("/Resources/Template/FriendUserItem.html");
                    $.ajax({
                        url: "Resources/Lib/GetFriendList.php",
                        type: "GET",
                        data: {},
                        dataType: "json",
                        success: function(n) {
                            $("#FriendContent").html($.processTemplateToText(i, n));
                            $("#FriendContent").on("click", ".UserFriend", function() {
                                var o = $(this).data("id");
                                $.ajax({
                                    url: "Resources/Lib/SetRelation.php",
                                    type: "GET",
                                    data: {
                                        target: o,
                                        Type: 1
                                    },
                                    dataType: "json",
                                    success: function(p) {
                                        $("#response").html(p.Result);
                                        $("#User" + o).remove();
                                        $("#FriendContent").append($.processTemplateToText(i, p))
                                    }
                                })
                            });
                            $("#FriendContent").on("click", ".UserBlock", function() {
                                var o = $(this).data("id");
                                $.ajax({
                                    url: "Resources/Lib/SetRelation.php",
                                    type: "GET",
                                    data: {
                                        target: o,
                                        Type: 2
                                    },
                                    dataType: "json",
                                    success: function(p) {
                                        $("#response").html(p.Result);
                                        $("#User" + o).remove();
                                        $("#FriendContent").append($.processTemplateToText(i, p))
                                    }
                                })
                            });
                            $("#FriendSearch").keypress(function(o) {
                                if (o.which == 13) {
                                    f.preventDefault();
                                    $("#searchfriend").click()
                                }
                            });
                            $("#searchfriend").click(function() {
                                var o = $("#FriendSearch").val();
                                if (o.length < 3) {
                                    $("#response").html("Please enter at least 3 characters to search for");
                                    $("#response").addClass("Invalid")
                                } else {
                                    $.ajax({
                                        url: "Resources/Lib/FriendSearch.php",
                                        type: "GET",
                                        data: {
                                            term: o
                                        },
                                        dataType: "json",
                                        success: function(p) {
                                            $("#AddFriendContent").html($.processTemplateToText(i, p));
                                            $("#AddFriendContent").on("click", ".UserFriend", function() {
                                                var q = $(this).data("id");
                                                $.ajax({
                                                    url: "Resources/Lib/SetRelation.php",
                                                    type: "GET",
                                                    data: {
                                                        target: q,
                                                        Type: 1
                                                    },
                                                    dataType: "json",
                                                    success: function(r) {
                                                        $("#response").html(r.Result);
                                                        $("#FriendContent").append($.processTemplateToText(i, r));
                                                        $("#AddFriendContent").html("")
                                                    }
                                                })
                                            });
                                            $("#AddFriendContent").on("click", ".UserBlock", function() {
                                                var q = $(this).data("id");
                                                $.ajax({
                                                    url: "Resources/Lib/SetRelation.php",
                                                    type: "GET",
                                                    data: {
                                                        target: q,
                                                        Type: 2
                                                    },
                                                    dataType: "json",
                                                    success: function(r) {
                                                        $("#response").html(r.Result);
                                                        $("#FriendContent").append($.processTemplateToText(i, r));
                                                        $("#AddFriendContent").html("")
                                                    }
                                                })
                                            })
                                        }
                                    })
                                }
                            })
                        }
                    })
                } else {
                    if (j.id == "Settings") {
                        var l = document.getElementById("MainContent");
                        var m = new Spinner(opts).spin(l);
                        list = 3;
                        $.ajax({
                            url: "/Resources/Template/Settings.html",
                            type: "GET",
                            data: {},
                            dataType: "text",
                            success: function(n) {
                                $("#PaneTitle").html("My Account");
                                $(".MainContent").setTemplate(n);
                                $(".MainContent").processTemplate(me);
                                $("#UserSettingsReset").click(function() {
                                    $("#response").html("");
                                    var o = document.getElementById("MainContent");
                                    var p = new Spinner(opts).spin(o);
                                    $.ajax({
                                        url: "Resources/Lib/NewAPIKey.php",
                                        type: "GET",
                                        data: {},
                                        dataType: "json",
                                        success: function(q) {
                                            p.stop();
                                            if (q.Result == "Error") {
                                                $("#response").html(q.Error)
                                            } else {
                                                me.APIKey = q.Result;
                                                $("#settingsapikey").val(q.Result);
                                                $("#response").html("Information Updated Successfully")
                                            }
                                        }
                                    })
                                });
                                $("#UserSettingsPassword").click(function() {
                                    $("#response").html("");
                                    var r = $("#pwd_old").val();
                                    var q = $("#pwd_new").val();
                                    var p = $("#pwd_new2").val();
                                    var o = {};
                                    if (r == "" || q == "" || p == "") {
                                        $("#response").html("You must confirm old password and enter a newpassword.")
                                    } else {
                                        if (q != p) {
                                            $("#response").html("New Passwords do not match.")
                                        } else {
                                            o.old_pwd = r;
                                            o.new_pwd = q;
                                            $.ajax({
                                                url: "Resources/Lib/UserPassword.php",
                                                type: "POST",
                                                data: o,
                                                dataType: "json",
                                                success: function(s) {
                                                    if (s.Result == "Error") {
                                                        $("#response").html("Failed to change password")
                                                    } else {
                                                        $("#response").html("Information Updated Successfully")
                                                    }
                                                }
                                            })
                                        }
                                    }
                                })
                            },
                            error: function(n) {}
                        })
                    } else {
                        if (j.id == "Admin") {
                            var l = document.getElementById("MainContent");
                            var m = new Spinner(opts).spin(l);
                            $.ajax({
                                url: "/Resources/Template/Admin.html",
                                type: "GET",
                                data: {},
                                dataType: "text",
                                success: function(o) {
                                    $(".MainContent").setTemplate(o);
                                    $(".MainContent").processTemplate();
                                    $.ajax({
                                        url: "Resources/Lib/Stats.php",
                                        type: "GET",
                                        data: {},
                                        dataType: "json",
                                        async: true,
                                        success: function(p) {
                                            $("#UpdateCount").html(p.Info);
                                            $("#LinkCount").html(p.Link);
                                            $("#OnlineCount").html(p.Online)
                                        }
                                    });
                                    var n;
                                    $.ajax({
                                        url: "/Resources/Template/AdminList.html",
                                        type: "GET",
                                        data: {},
                                        dataType: "text",
                                        async: false,
                                        success: function(p) {
                                            n = p
                                        }
                                    });
                                    $.ajax({
                                        url: "Resources/Lib/AdminGetUsers.php",
                                        type: "GET",
                                        data: {
                                            term: adminSearch,
                                            page: adminPage,
                                            count: adminIncrement
                                        },
                                        dataType: "json",
                                        success: function(q) {
                                            if (q.Error) {
                                                var p = "<div class='AdminForms'>";
                                                p += "<p class='PageInfo'>You have navigated to a page that doesn't exist.</p> ";
                                                p += "</div>";
                                                $(".AdminForms").html(p)
                                            } else {
                                                adminTotal = q.Count;
                                                adminPage = q.Page;
                                                adminPages = q.Pages;
                                                $("#AdminContent").setTemplate(n);
                                                $("#AdminContent").processTemplate(q)
                                            }
                                        }
                                    });
                                    $("#AdminContent").on("click", "#AdminAction", function() {
                                        var q = document.getElementById("MainContent");
                                        var r = new Spinner(opts).spin(q);
                                        var p = [];
                                        $(".Highlight").each(function() {
                                            var s = $(this).attr("id");
                                            p.push(s)
                                        });
                                        if (p.length == 0) {
                                            r.stop()
                                        } else {
                                            $.each(p, function(s, t) {
                                                switch ($("#AdminPerform").val()) {
                                                    case "Ban":
                                                        $.ajax({
                                                            url: "Resources/Lib/AdminBan.php",
                                                            type: "GET",
                                                            data: {
                                                                ban: 1,
                                                                banid: t
                                                            },
                                                            dataType: "json",
                                                            success: function(u) {
                                                                r.stop();
                                                                if (u.Error) {
                                                                    $("#response").html("Error updating User")
                                                                } else {
                                                                    $("#response").html("Banned user");
                                                                    $("#" + u.ID + " #AdminTableBan").html(u.Banned)
                                                                }
                                                            }
                                                        });
                                                        break;
                                                    case "UnBan":
                                                        $.ajax({
                                                            url: "Resources/Lib/AdminBan.php",
                                                            type: "GET",
                                                            data: {
                                                                ban: 0,
                                                                banid: t
                                                            },
                                                            dataType: "json",
                                                            success: function(u) {
                                                                r.stop();
                                                                if (u.Error) {
                                                                    $("#response").html("Error updating User")
                                                                } else {
                                                                    $("#response").html("Removed ban from user");
                                                                    $("#" + u.ID + " #AdminTableBan").html(u.Banned)
                                                                }
                                                            }
                                                        });
                                                        break;
                                                    case "Approve":
                                                        $.ajax({
                                                            url: "Resources/Lib/AdminApprove.php",
                                                            type: "GET",
                                                            data: {
                                                                approve: 1,
                                                                approveid: t
                                                            },
                                                            dataType: "json",
                                                            success: function(u) {
                                                                r.stop();
                                                                if (u.Error) {
                                                                    $("#response").html("Error updating User")
                                                                } else {
                                                                    $("#response").html("Approved User");
                                                                    $("#" + u.ID + " #AdminTableApproved").html(u.Approved)
                                                                }
                                                            }
                                                        });
                                                        break;
                                                    case "UnApprove":
                                                        $.ajax({
                                                            url: "Resources/Lib/AdminApprove.php",
                                                            type: "GET",
                                                            data: {
                                                                approve: 0,
                                                                approveid: t
                                                            },
                                                            dataType: "json",
                                                            success: function(u) {
                                                                r.stop();
                                                                if (u.Error) {
                                                                    $("#response").html("Error updating User")
                                                                } else {
                                                                    $("#response").html("UnApproved User");
                                                                    $("#" + u.ID + " #AdminTableApproved").html(u.Approved)
                                                                }
                                                            }
                                                        });
                                                        break;
                                                    case "Delete":
                                                        $.ajax({
                                                            url: "Resources/Lib/AdminDelete.php",
                                                            type: "GET",
                                                            data: {
                                                                deleteid: t
                                                            },
                                                            dataType: "json",
                                                            success: function(u) {
                                                                r.stop();
                                                                if (u.Error) {
                                                                    $("#response").html("Error Removing User")
                                                                } else {
                                                                    $("#response").html("User Deleted");
                                                                    $("#" + u.ID).remove()
                                                                }
                                                            }
                                                        });
                                                        break;
                                                    case "Reset":
                                                        $.ajax({
                                                            url: "Resources/Lib/AdminPasswordReset.php",
                                                            type: "GET",
                                                            data: {
                                                                resetid: t
                                                            },
                                                            dataType: "json",
                                                            success: function(u) {
                                                                r.stop();
                                                                if (u.Error) {
                                                                    $("#response").html("Error Resetting Password")
                                                                } else {
                                                                    $("#response").html("Sent user new password.")
                                                                }
                                                            }
                                                        });
                                                        break;
                                                    case "Resend":
                                                        $.ajax({
                                                            url: "Resources/Lib/AdminResendActiviation.php",
                                                            type: "GET",
                                                            data: {
                                                                resendid: t
                                                            },
                                                            dataType: "json",
                                                            success: function(u) {
                                                                r.stop();
                                                                if (u.Error) {
                                                                    $("#response").html("Error Resending Activation")
                                                                } else {
                                                                    $("#response").html("Resent activation to user.")
                                                                }
                                                            }
                                                        });
                                                        break;
                                                    case "Mod":
                                                        $.ajax({
                                                            url: "Resources/Lib/AdminModerator.php",
                                                            type: "GET",
                                                            data: {
                                                                mod: 3,
                                                                modid: t
                                                            },
                                                            dataType: "json",
                                                            success: function(u) {
                                                                r.stop();
                                                                if (u.Error) {
                                                                    $("#response").html("Error setting user as moderator")
                                                                } else {
                                                                    $("#response").html("User is now moderator");
                                                                    if (u.Level > 1) {
                                                                        $("#" + u.ID + " #AdminTableMod").html(1)
                                                                    } else {
                                                                        $("#" + u.ID + " #AdminTableMod").html(0)
                                                                    }
                                                                }
                                                            }
                                                        });
                                                        break;
                                                    case "UnMod":
                                                        $.ajax({
                                                            url: "Resources/Lib/AdminModerator.php",
                                                            type: "GET",
                                                            data: {
                                                                mod: 1,
                                                                modid: t
                                                            },
                                                            dataType: "json",
                                                            success: function(u) {
                                                                r.stop();
                                                                if (u.Error) {
                                                                    $("#response").html("Error removing user as moderator")
                                                                } else {
                                                                    $("#response").html("User is No Longer moderator");
                                                                    if (u.Level > 1) {
                                                                        $("#" + u.ID + " #AdminTableMod").html(1)
                                                                    } else {
                                                                        $("#" + u.ID + " #AdminTableMod").html(0)
                                                                    }
                                                                }
                                                            }
                                                        });
                                                        break
                                                }
                                                $(".Highlight").each(function() {
                                                    $(this).removeClass("Highlight")
                                                })
                                            })
                                        }
                                    });
                                    $("#AdminContent").on("click", ".TableContainer", function() {
                                        var p = $(this).attr("id");
                                        if ($(this).hasClass("Highlight")) {
                                            $("#" + p).removeClass("Highlight")
                                        } else {
                                            $("#" + p).addClass("Highlight")
                                        }
                                    });
                                    $("#AdminContent").on("click", ".AdminPrev", function() {
                                        var p = document.getElementById("MainContent");
                                        var q = new Spinner(opts).spin(p);
                                        adminPage--;
                                        if (adminPage < 0) {
                                            adminPage = 0
                                        }
                                        $.ajax({
                                            url: "Resources/Lib/AdminGetUsers.php",
                                            type: "GET",
                                            data: {
                                                term: adminSearch,
                                                page: adminPage,
                                                count: adminIncrement
                                            },
                                            dataType: "json",
                                            success: function(r) {
                                                q.stop();
                                                if (r.Error) {
                                                    var s = "<p class='PageInfo'>You have navigated to a page that doesn't exist.</p> ";
                                                    $(".ContentPage").html(s)
                                                } else {
                                                    adminTotal = r.Count;
                                                    adminPage = r.Page;
                                                    adminPages = r.Pages;
                                                    $("#AdminContent").setTemplate(n);
                                                    $("#AdminContent").processTemplate(r)
                                                }
                                            }
                                        })
                                    });
                                    $("#AdminContent").on("click", ".AdminNext", function() {
                                        var p = document.getElementById("MainContent");
                                        var q = new Spinner(opts).spin(p);
                                        adminPage++;
                                        if (adminPage > adminPages) {
                                            adminPage = adminPages
                                        }
                                        $.ajax({
                                            url: "Resources/Lib/AdminGetUsers.php",
                                            type: "GET",
                                            data: {
                                                term: adminSearch,
                                                page: adminPage,
                                                count: adminIncrement
                                            },
                                            dataType: "json",
                                            success: function(r) {
                                                q.stop();
                                                if (r.Error) {
                                                    var s = "<p class='PageInfo'>You have navigated to a page that doesn't exist.</p> ";
                                                    $(".ContentPage").html(s)
                                                } else {
                                                    adminTotal = r.Count;
                                                    adminPage = r.Page;
                                                    adminPages = r.Pages;
                                                    $("#AdminContent").setTemplate(n);
                                                    $("#AdminContent").processTemplate(r)
                                                }
                                            }
                                        })
                                    });
                                    $("#AdminContent").on("click", ".AdminFirst", function() {
                                        var p = document.getElementById("MainContent");
                                        var q = new Spinner(opts).spin(p);
                                        adminPage = 0;
                                        $.ajax({
                                            url: "Resources/Lib/AdminGetUsers.php",
                                            type: "GET",
                                            data: {
                                                term: adminSearch,
                                                page: adminPage,
                                                count: adminIncrement
                                            },
                                            dataType: "json",
                                            success: function(r) {
                                                q.stop();
                                                if (r.Error) {
                                                    var s = "<p class='PageInfo'>You have navigated to a page that doesn't exist.</p> ";
                                                    $(".ContentPage").html(s)
                                                } else {
                                                    adminTotal = r.Count;
                                                    adminPage = r.Page;
                                                    adminPages = r.Pages;
                                                    $("#AdminContent").setTemplate(n);
                                                    $("#AdminContent").processTemplate(r)
                                                }
                                            }
                                        })
                                    });
                                    $("#AdminContent").on("click", ".AdminLast", function() {
                                        var p = document.getElementById("MainContent");
                                        var q = new Spinner(opts).spin(p);
                                        adminPage = adminPages;
                                        $.ajax({
                                            url: "Resources/Lib/AdminGetUsers.php",
                                            type: "GET",
                                            data: {
                                                term: adminSearch,
                                                page: adminPage,
                                                count: adminIncrement
                                            },
                                            dataType: "json",
                                            success: function(r) {
                                                q.stop();
                                                if (r.Error) {
                                                    var s = "<p class='PageInfo'>You have navigated to a page that doesn't exist.</p> ";
                                                    $(".ContentPage").html(s)
                                                } else {
                                                    adminTotal = r.Count;
                                                    adminPage = r.Page;
                                                    adminPages = r.Pages;
                                                    $("#AdminContent").setTemplate(n);
                                                    $("#AdminContent").processTemplate(r)
                                                }
                                            }
                                        })
                                    });
                                    $("#AdminContent").on("click", ".AdminPage", function() {
                                        var p = document.getElementById("MainContent");
                                        var q = new Spinner(opts).spin(p);
                                        adminPage = $(this).data("id");
                                        if (adminPage > adminPages) {
                                            adminPage = adminPages
                                        }
                                        if (adminPage < 0) {
                                            adminPage = 0
                                        }
                                        $.ajax({
                                            url: "Resources/Lib/AdminGetUsers.php",
                                            type: "GET",
                                            data: {
                                                term: adminSearch,
                                                page: adminPage,
                                                count: adminIncrement
                                            },
                                            dataType: "json",
                                            success: function(r) {
                                                q.stop();
                                                if (r.Error) {
                                                    var s = "<p class='PageInfo'>You have navigated to a page that doesn't exist.</p> ";
                                                    $(".ContentPage").html(s)
                                                } else {
                                                    adminTotal = r.Count;
                                                    adminPage = r.Page;
                                                    adminPages = r.Pages;
                                                    $("#AdminContent").setTemplate(n);
                                                    $("#AdminContent").processTemplate(r)
                                                }
                                            }
                                        })
                                    });
                                    $("#adminsearch").keyup(function() {
                                        var p = this;
                                        if (this.timer) {
                                            clearTimeout(this.timer)
                                        }
                                        this.timer = setTimeout(function() {
                                            var q = document.getElementById("MainContent");
                                            var r = new Spinner(opts).spin(q);
                                            adminSearch = $("#adminsearch").val();
                                            adminPage = 0;
                                            $.ajax({
                                                url: "Resources/Lib/AdminGetUsers.php",
                                                type: "GET",
                                                data: {
                                                    term: adminSearch,
                                                    page: adminPage,
                                                    count: adminIncrement
                                                },
                                                dataType: "json",
                                                success: function(t) {
                                                    r.stop();
                                                    if (t.Error) {
                                                        var s = "<p class='PageInfo'>You have navigated to a page that doesn't exist.</p> ";
                                                        $(".ContentPage").html(s)
                                                    } else {
                                                        adminTotal = t.Count;
                                                        adminPage = t.Page;
                                                        adminPages = t.Pages;
                                                        $("#AdminContent").setTemplate(n);
                                                        $("#AdminContent").processTemplate(t)
                                                    }
                                                }
                                            })
                                        }, 500)
                                    })
                                }
                            })
                        } else {
                            if (j.id == "AddRoom") {
                                var g = 0;
                                var h = new Array();
                                var l = document.getElementById("MainContent");
                                var m = new Spinner(opts).spin(l);
                                var e = "/Resources/Template/AddRoom.html";
                                $.ajax({
                                    url: e,
                                    type: "GET",
                                    data: {},
                                    dataType: "text",
                                    success: function(n) {
                                        m.stop();
                                        $(".MainContent").setTemplate(n);
                                        $(".MainContent").processTemplate();
                                        $("#AddRoomContainer").hide();
                                        $("#private").hide();
                                        if (me.Level < 3) {
                                            $("#persist").hide()
                                        }
                                        $("#TitleSearch").keyup(function() {
                                            var o = this;
                                            if (this.timer) {
                                                clearTimeout(this.timer)
                                            }
                                            this.timer = setTimeout(function() {
                                                var p = document.getElementById("MainContent");
                                                var q = new Spinner(opts).spin(p);
                                                $("#response").html("");
                                                $.ajax({
                                                    url: "Resources/Lib/AddRoomSearch.php",
                                                    type: "GET",
                                                    data: {
                                                        term: $("#TitleSearch").val(),
                                                        all: 1
                                                    },
                                                    dataType: "json",
                                                    success: function(s) {
                                                        q.stop();
                                                        var r = s;
                                                        $.ajax({
                                                            url: "/Resources/Template/AddRoomList.html",
                                                            type: "GET",
                                                            data: {},
                                                            dataType: "text",
                                                            success: function(t) {
                                                                q.stop();
                                                                $("#TitleSearchContent").setTemplate(t);
                                                                $("#TitleSearchContent").processTemplate(r)
                                                            }
                                                        })
                                                    }
                                                })
                                            }, 500)
                                        });
                                        $("#TitleSearchContent").on("click", ".NewTitle", function() {
                                            $("#response").html("");
                                            uploadID = $(this).data("roomid");
                                            uploadType = $(this).data("tid");
                                            $("#AddRoomContainer").show();
                                            $("#TitleSearchContent").hide()
                                        });
                                        $("#CancelRoom").click(function() {
                                            $("#AddRoomContainer").hide();
                                            $("#TitleSearchContent").show()
                                        });
                                        $("#CreateRoom").click(function() {
                                            var o = 1;
                                            if ($("#persistent").is(":checked")) {
                                                o = 0
                                            }
                                            $.ajax({
                                                url: "Resources/Lib/AddRoom.php",
                                                type: "GET",
                                                data: {
                                                    parent: uploadID,
                                                    tid: uploadType,
                                                    name: $("#roomname").val(),
                                                    isprivate: $("#isprivate").val(),
                                                    password: $("#password").val(),
                                                    persist: o
                                                },
                                                dataType: "json",
                                                success: function(p) {
                                                    m.stop();
                                                    if (p.Result == "Failed") {
                                                        $("#response").html("Failed to add Room.")
                                                    } else {
                                                        $("#response").html("Room Added to List.")
                                                    }
                                                }
                                            })
                                        });
                                        $("#MakePrivate").click(function() {
                                            $("#isprivate").val("1");
                                            $("#MakePrivateBox").hide();
                                            $("#private").show()
                                        });
                                        $("#MakePublic").click(function() {
                                            $("#isprivate").val("0");
                                            $("#MakePrivateBox").show();
                                            $("#private").hide()
                                        });
                                        $(".pcBtn").click(function() {
                                            if (g < maxPassCode) {
                                                g++;
                                                h.push($(this).data("val"));
                                                $("#passBtn").empty();
                                                var o = "";
                                                $.each(h, function(p, r) {
                                                    if (r < 10) {
                                                        o += "0" + r.toString()
                                                    } else {
                                                        o += r.toString()
                                                    }
                                                    var q = PassCode(r);
                                                    $("#passBtn").append(q)
                                                });
                                                $("#password").val(parseInt(o, 16))
                                            }
                                        });
                                        $(".passButtons").click(function() {
                                            if (g > 0) {
                                                g--;
                                                h.pop();
                                                $("#passBtn").empty();
                                                var o = "";
                                                $.each(h, function(p, r) {
                                                    if (r < 10) {
                                                        o += "0" + r.toString()
                                                    } else {
                                                        o += r.toString()
                                                    }
                                                    var q = PassCode(r);
                                                    $("#passBtn").append(q)
                                                });
                                                $("#password").val(parseInt(o, 16))
                                            }
                                        })
                                    }
                                })
                            } else {
                                if (j.id == "AddTitle") {
                                    var l = document.getElementById("MainContent");
                                    var m = new Spinner(opts).spin(l);
                                    var e = "/Resources/Template/AddTitle.html";
                                    if (me.Level >= 3) {
                                        e = "/Resources/Template/AddTitleAdmin.html"
                                    }
                                    $.ajax({
                                        url: e,
                                        type: "GET",
                                        data: {},
                                        dataType: "text",
                                        success: function(n) {
                                            m.stop();
                                            $("#PaneTitle").html("Add Title");
                                            $(".MainContent").setTemplate(n);
                                            $(".MainContent").processTemplate();
                                            if (me.Level >= 3) {
                                                $("#tabs").tabs()
                                            }
                                            $("#TitleSearch").keyup(function() {
                                                var o = this;
                                                if (this.timer) {
                                                    clearTimeout(this.timer)
                                                }
                                                this.timer = setTimeout(function() {
                                                    var p = document.getElementById("MainContent");
                                                    var q = new Spinner(opts).spin(p);
                                                    $("#response").html("");
                                                    $.ajax({
                                                        url: "Resources/Lib/AddTitleSearch.php",
                                                        type: "GET",
                                                        data: {
                                                            term: $("#TitleSearch").val(),
                                                            all: 1
                                                        },
                                                        dataType: "json",
                                                        success: function(s) {
                                                            q.stop();
                                                            var r = s;
                                                            $.ajax({
                                                                url: "/Resources/Template/AddTitleList.html",
                                                                type: "GET",
                                                                data: {},
                                                                dataType: "text",
                                                                success: function(t) {
                                                                    q.stop();
                                                                    $("#TitleSearchContent").setTemplate(t);
                                                                    $("#TitleSearchContent").processTemplate(r)
                                                                }
                                                            })
                                                        }
                                                    })
                                                }, 500)
                                            });
                                            $("#xbcAdd").click(function() {
                                                $("#response").html("");
                                                if ($("#xbcTitle").val() != "" && $("#xbcTitleID").val() != "") {
                                                    $.ajax({
                                                        url: "Resources/Lib/AdminAddTitle.php",
                                                        type: "GET",
                                                        data: {
                                                            title: $("#xbcTitle").val(),
                                                            titleid: $("#xbcTitleID").val(),
                                                            type: 3
                                                        },
                                                        dataType: "json",
                                                        success: function(o) {
                                                            m.stop();
                                                            if (o.Result == "Error") {
                                                                $("#response").html("Failed to add Title")
                                                            } else {
                                                                $("#response").html("Added Title Successfully")
                                                            }
                                                        }
                                                    })
                                                } else {
                                                    $("#response").html("Please fill in all fields.")
                                                }
                                            });
                                            $("#xbmAdd").click(function() {
                                                $("#response").html("");
                                                if ($("#xbmTitle").val() != "" && $("#xbmTitleID").val() != "") {
                                                    $.ajax({
                                                        url: "Resources/Lib/AdminAddTitle.php",
                                                        type: "GET",
                                                        data: {
                                                            title: $("#xbmTitle").val(),
                                                            titleid: $("#xbmTitleID").val(),
                                                            type: 1
                                                        },
                                                        dataType: "json",
                                                        success: function(o) {
                                                            m.stop();
                                                            if (o.Result == "Error") {
                                                                $("#response").html("Failed to add Title")
                                                            } else {
                                                                $("#response").html("Added Title Successfully")
                                                            }
                                                        }
                                                    })
                                                } else {
                                                    $("#response").html("Please fill in all fields.")
                                                }
                                            });
                                            $("#hbAdd").click(function() {
                                                $("#response").html("");
                                                if ($("#hbTitle").val() != "") {
                                                    $.ajax({
                                                        url: "Resources/Lib/AdminAddTitle.php",
                                                        type: "GET",
                                                        data: {
                                                            title: $("#hbTitle").val(),
                                                            hbTitleID: $("#hbTitleID").val(),
                                                            type: 4,
                                                            search: $("#hbSearchTerm").val()
                                                        },
                                                        dataType: "json",
                                                        success: function(o) {
                                                            m.stop();
                                                            if (o.Result == "Error") {
                                                                $("#response").html("Failed to add Title")
                                                            } else {
                                                                $("#response").html("Added Title Successfully")
                                                            }
                                                        }
                                                    })
                                                } else {
                                                    $("#response").html("Please enter information before clicking add")
                                                }
                                            });
                                            $("#TitleSearchContent").on("click", ".NewTitle", function() {
                                                $("#response").html("");
                                                var o = $(this).data("name");
                                                var p = $(this).data("id");
                                                $.ajax({
                                                    url: "Resources/Lib/AddTitle.php",
                                                    type: "GET",
                                                    data: {
                                                        title: encodeURIComponent(o),
                                                        id: p,
                                                        type: 1
                                                    },
                                                    dataType: "json",
                                                    success: function(q) {
                                                        if (q.Result == "Exists") {
                                                            $("#response").html("Title is already in our list")
                                                        } else {
                                                            if (q.Result == "Error") {
                                                                $("#response").html("Error Adding Title " + q.String)
                                                            } else {
                                                                if (q.Result == "Added") {
                                                                    $("#response").html("Title Added Successfully")
                                                                } else {
                                                                    $("#response").html("Unknown Error Adding Title")
                                                                }
                                                            }
                                                        }
                                                    }
                                                })
                                            })
                                        }
                                    })
                                } else {
                                    if (j.id == "ReadLog") {
                                        var l = document.getElementById("MainContent");
                                        var m = new Spinner(opts).spin(l);
                                        var e = "/Resources/Template/ReadLog.html";
                                        $.ajax({
                                            url: e,
                                            type: "GET",
                                            data: {},
                                            dataType: "text",
                                            success: function(n) {
                                                m.stop();
                                                $(".MainContent").setTemplate(n);
                                                $(".MainContent").processTemplate();
                                                var o = $("#singleupload1").uploadFile({
                                                    url: "/Resources/Lib/UploadLog.php",
                                                    multiple: false,
                                                    autoSubmit: true,
                                                    fileName: "myfile",
                                                    maxFileCount: 1,
                                                    showStatusAfterSuccess: false,
                                                    dragDropStr: "<span><b>drag and drop here</b></span><br/>",
                                                    formData: {},
                                                    abortStr: "abort",
                                                    cancelStr: "cancel",
                                                    doneStr: "done",
                                                    multiDragErrorStr: "Multiple Upload Failed.",
                                                    extErrorStr: "Unsupported ext:",
                                                    sizeErrorStr: "Filesize to large:",
                                                    uploadErrorStr: "Upload failed",
                                                    returnType: "json",
                                                    uploadButtonClass: "page dark",
                                                    onSubmit: function(p) {
                                                        $("#response").html("")
                                                    },
                                                    onSuccess: function(s, u, t) {
                                                        var q = u;
                                                        var p = document.getElementById("MainContent");
                                                        var r = new Spinner(opts).spin(p);
                                                        $.ajax({
                                                            url: "/Resources/Template/ReadLogList.html",
                                                            type: "GET",
                                                            data: {},
                                                            dataType: "text",
                                                            success: function(v) {
                                                                r.stop();
                                                                $("#LogContent").setTemplate(v);
                                                                $("#LogContent").processTemplate(q)
                                                            }
                                                        })
                                                    },
                                                    onError: function(r, p, q) {
                                                        $("#response").html("<br/>Error for: " + JSON.stringify(r))
                                                    }
                                                })
                                            }
                                        })
                                    } else {
                                        if (j.id == "Upload") {
                                            var l = document.getElementById("MainContent");
                                            var m = new Spinner(opts).spin(l);
                                            var e = "/Resources/Template/UploadContent.html";
                                            uploadID = "";
                                            $.ajax({
                                                url: e,
                                                type: "GET",
                                                data: {},
                                                dataType: "text",
                                                success: function(n) {
                                                    m.stop();
                                                    $("#PaneTitle").html("Add Title");
                                                    $(".MainContent").setTemplate(n);
                                                    $(".MainContent").processTemplate();
                                                    $("#uploadContainer").hide();
                                                    $("#TitleSearch").keyup(function() {
                                                        var p = this;
                                                        if (this.timer) {
                                                            clearTimeout(this.timer)
                                                        }
                                                        this.timer = setTimeout(function() {
                                                            var q = document.getElementById("MainContent");
                                                            var r = new Spinner(opts).spin(q);
                                                            $("#response").html("");
                                                            $.ajax({
                                                                url: "Resources/Lib/UploadTitleSearch.php",
                                                                type: "GET",
                                                                data: {
                                                                    term: $("#TitleSearch").val(),
                                                                    all: 1
                                                                },
                                                                dataType: "json",
                                                                success: function(s) {
                                                                    r.stop();
                                                                    var t = s;
                                                                    $.ajax({
                                                                        url: "/Resources/Template/UploadTitleList.html",
                                                                        type: "GET",
                                                                        data: {},
                                                                        dataType: "text",
                                                                        success: function(u) {
                                                                            r.stop();
                                                                            $("#TitleSearchContent").setTemplate(u);
                                                                            $("#TitleSearchContent").processTemplate(t)
                                                                        }
                                                                    })
                                                                }
                                                            })
                                                        }, 500)
                                                    });
                                                    $("#TitleSearchContent").on("click", ".NewTitle", function() {
                                                        $("#response").html("");
                                                        if (uploadID == $(this).data("tid")) {
                                                            $(this).removeClass("Highlight");
                                                            uploadID = "";
                                                            uploadType = 1;
                                                            $("#uploadContainer").hide()
                                                        } else {
                                                            $(".Highlight").each(function() {
                                                                $(this).removeClass("Highlight")
                                                            });
                                                            $(this).addClass("Highlight");
                                                            uploadID = $(this).data("tid");
                                                            uploadType = $(this).data("type");
                                                            $("#uploadContainer").show()
                                                        }
                                                    });
                                                    var o = $("#singleupload1").uploadFile({
                                                        url: "/Resources/Lib/UploadTitleUpdate.php",
                                                        multiple: false,
                                                        autoSubmit: false,
                                                        fileName: "myfile",
                                                        maxFileCount: 1,
                                                        showStatusAfterSuccess: true,
                                                        dragDropStr: "<span><b>drag and drop here</b></span>",
                                                        dynamicFormData: function() {
                                                            var p = 0;
                                                            if ($("#official").is(":checked")) {
                                                                p = 1
                                                            }
                                                            var q = {
                                                                tid: uploadID,
                                                                type: uploadType,
                                                                official: p
                                                            };
                                                            return q
                                                        },
                                                        abortStr: "abort",
                                                        cancelStr: "cancel",
                                                        doneStr: "done",
                                                        multiDragErrorStr: "Multiple Upload Failed.",
                                                        extErrorStr: "Unsupported ext:",
                                                        sizeErrorStr: "Filesize to large:",
                                                        uploadErrorStr: "Upload failed",
                                                        returnType: "json",
                                                        uploadButtonClass: "page dark",
                                                        onSubmit: function(p) {
                                                            $("#response").html("")
                                                        },
                                                        onSuccess: function(p, q, r) {
                                                            $("#response").html(q.Message)
                                                        },
                                                        onError: function(r, p, q) {
                                                            $("#response").html("<br/>Error for: " + JSON.stringify(r))
                                                        }
                                                    });
                                                    $("#StartUpload").click(function() {
                                                        o.startUpload()
                                                    })
                                                }
                                            })
                                        } else {
                                            if (j.id == "Approve") {
                                                var l = document.getElementById("MainContent");
                                                var m = new Spinner(opts).spin(l);
                                                approvePage = 0;
                                                $.ajax({
                                                    url: "/Resources/Template/ApproveCovers.html",
                                                    type: "GET",
                                                    data: {},
                                                    dataType: "text",
                                                    success: function(n) {
                                                        m.stop();
                                                        $(".MainContent").setTemplate(n);
                                                        $(".MainContent").processTemplate();
                                                        ApproveList(approve.Index, approve.Step, true);
                                                        $("#approvesearch").keyup(function() {
                                                            window.scrollTo(0, 0);
                                                            var o = this;
                                                            var p = $("#approvesearch").val();
                                                            if (p != approveString) {
                                                                if (this.timer) {
                                                                    clearTimeout(this.timer)
                                                                }
                                                                this.timer = setTimeout(function() {
                                                                    approveString = p;
                                                                    approve.Index = 0;
                                                                    ApproveList(0, approve.Step, true)
                                                                }, 500)
                                                            }
                                                        });
                                                        $(".MainContent").on("click", ".Approve", function() {
                                                            var o = document.getElementById("MainContent");
                                                            var p = new Spinner(opts).spin(o);
                                                            var q = $(this).data("id");
                                                            $.ajax({
                                                                url: "Resources/Lib/CoverSetState.php",
                                                                type: "GET",
                                                                data: {
                                                                    cid: q,
                                                                    approve: 1
                                                                },
                                                                dataType: "json",
                                                                success: function(r) {
                                                                    p.stop();
                                                                    if (r.Result == "Error") {
                                                                        $("#response").html("Approving Cover Failed")
                                                                    } else {
                                                                        $("#response").html("Approving Cover Successful");
                                                                        $("#" + q).remove();
                                                                        ApproveList(approve.Index + approve.Step, 1);
                                                                        approve.Total--
                                                                    }
                                                                }
                                                            })
                                                        });
                                                        $(".MainContent").on("click", ".Reject", function() {
                                                            var o = document.getElementById("MainContent");
                                                            var p = new Spinner(opts).spin(o);
                                                            var q = $(this).data("id");
                                                            $.ajax({
                                                                url: "Resources/Lib/CoverSetState.php",
                                                                type: "GET",
                                                                data: {
                                                                    cid: q,
                                                                    approve: 0
                                                                },
                                                                dataType: "json",
                                                                success: function(r) {
                                                                    p.stop();
                                                                    if (r.Result == "Error") {
                                                                        $("#response").html("Rejecting Cover Failed")
                                                                    } else {
                                                                        $("#response").html("Rejecting Cover Successful");
                                                                        $("#" + q).remove();
                                                                        ApproveList(approve.Index + approve.Step, 1);
                                                                        approve.Total--
                                                                    }
                                                                }
                                                            })
                                                        });
                                                        $(".MainContent").on("click", ".ApproveNext", function() {
                                                            approve.Index += approve.Step;
                                                            if (approve.Index > approve.Total) {
                                                                approve.Index = approve.Total
                                                            }
                                                            ApproveList(approve.Index, approve.Step, true)
                                                        });
                                                        $(".MainContent").on("click", ".ApprovePrev", function() {
                                                            approve.Index -= approve.Step;
                                                            if (approve.Index < 0) {
                                                                approve.Index = 0
                                                            }
                                                            ApproveList(approve.Index, approve.Step, true)
                                                        });
                                                        $(".MainContent").on("click", ".ApprovePage", function() {
                                                            approve.Index = $(this).data("id") * approve.Step;
                                                            if (approve.Index > approve.Total) {
                                                                approve.Index = approve.Total
                                                            }
                                                            if (approve.Index < 0) {
                                                                approve.Index = 0
                                                            }
                                                            ApproveList(approve.Index, approve.Step, true)
                                                        });
                                                        $(".MainContent").on("click", ".ApproveLast", function() {
                                                            approve.Index = (approve.Pages - 1) * approve.Step;
                                                            ApproveList(approve.Index, approve.Step, true)
                                                        });
                                                        $(".MainContent").on("click", ".ApproveFirst", function() {
                                                            approve.Index = 0;
                                                            ApproveList(approve.Index, approve.Step, true)
                                                        })
                                                    }
                                                })
                                            } else {
                                                if (j.id == "Updater") {
                                                    var l = document.getElementById("MainContent");
                                                    var m = new Spinner(opts).spin(l);
                                                    approvePage = 0;
                                                    $.ajax({
                                                        url: "/Resources/Template/Updater.html",
                                                        type: "GET",
                                                        data: {},
                                                        dataType: "text",
                                                        success: function(n) {
                                                            m.stop();
                                                            $(".MainContent").setTemplate(n);
                                                            $(".MainContent").processTemplate();
                                                            var o = $("#singleupload1").uploadFile({
                                                                url: "/Resources/Lib/UploadUpdate.php",
                                                                multiple: false,
                                                                autoSubmit: true,
                                                                fileName: "myfile",
                                                                maxFileCount: 1,
                                                                showStatusAfterSuccess: false,
                                                                dragDropStr: "<span><b>drag and drop here</b></span><br/>",
                                                                dynamicFormData: function() {
                                                                    var u = $("#majorversion").val();
                                                                    var t = $("#minorversion").val();
                                                                    var q = $("#revision").val();
                                                                    var s = $("#VersionType").val();
                                                                    var r = $("#UpdateType").val();
                                                                    var v = $("#UpdateClass").val();
                                                                    var p = {
                                                                        majorversion: u,
                                                                        minorversion: t,
                                                                        revision: q,
                                                                        versiontype: s,
                                                                        type: r,
                                                                        audience: v
                                                                    };
                                                                    return p
                                                                },
                                                                abortStr: "abort",
                                                                cancelStr: "cancel",
                                                                doneStr: "done",
                                                                multiDragErrorStr: "Multiple Upload Failed.",
                                                                extErrorStr: "Unsupported ext:",
                                                                sizeErrorStr: "Filesize to large:",
                                                                uploadErrorStr: "Upload failed",
                                                                returnType: "json",
                                                                uploadButtonClass: "page dark",
                                                                onSubmit: function(p) {
                                                                    $("#response").html("")
                                                                },
                                                                onSuccess: function(p, q, r) {},
                                                                onError: function(r, p, q) {
                                                                    $("#response").html("<br/>Error for: " + JSON.stringify(r))
                                                                }
                                                            })
                                                        }
                                                    })
                                                } else {
                                                    if (j.id == "ShowUpdates") {
                                                        var l = document.getElementById("MainContent");
                                                        var m = new Spinner(opts).spin(l);
                                                        approvePage = 0;
                                                        $.ajax({
                                                            url: "/Resources/Template/ShowUpdates.html",
                                                            type: "GET",
                                                            data: {},
                                                            dataType: "text",
                                                            success: function(n) {
                                                                m.stop();
                                                                $(".MainContent").setTemplate(n);
                                                                $(".MainContent").processTemplate();
                                                                $.ajax({
                                                                    url: "Resources/Lib/GetUpdateList.php",
                                                                    type: "GET",
                                                                    data: {},
                                                                    dataType: "json",
                                                                    success: function(q) {
                                                                        var o = $.createTemplateURL("/Resources/Template/ShowUpdateList.html");
                                                                        var p = $.processTemplateToText(o, q);
                                                                        $("#ShowUpdateContent").html(p)
                                                                    }
                                                                })
                                                            }
                                                        })
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    })
});

function ApproveList(i, b, f) {
    var c = document.getElementById("MainContent");
    var h = new Spinner(opts).spin(c);
    $.ajax({
        url: "Resources/Lib/CoverApproval.php",
        type: "GET",
        data: {},
        dataType: "json",
        async: false,
        success: function(k) {
            approve.List = k.Covers;
            approve.Total = k.Total
        }
    });
    var a = $.createTemplateURL("/Resources/Template/ApproveCoverListItem.html");
    var g = $.createTemplateURL("/Resources/Template/ApproveCoversPage.html");
    if (f) {
        $(".ApproveList").html("")
    }
    var e = approve.List;
    if (approveString != "") {
        e = $.grep(e, function(l, k) {
            if (l.Name.toLowerCase().indexOf(approveString.toLowerCase()) > -1) {
                return true
            }
            if (l.TitleID == approveString) {
                return true
            }
            return false
        })
    }
    approve.Total = e.length;
    var j = i + b;
    if (j > approve.Total) {
        j = approve.Total
    }
    e = e.slice(i, j);
    $.each(e, function(k, l) {
        var m = $.processTemplateToText(a, l);
        $(".ApproveList").append(m)
    });
    approve.Page = 0;
    if (approve.Index > 0) {
        approve.Page = Math.floor(approve.Index / approve.Step)
    }
    approve.Pages = 0;
    if (approve.Total > 0) {
        approve.Pages = Math.ceil(approve.Total / approve.Step)
    }
    var d = $.processTemplateToText(g, approve);
    $(".ApprovePages").html(d);
    h.stop()
}

function getMeFull() {
    $("#LoginPanel").html("");
    var a = document.getElementById("MainContent");
    var b = new Spinner(opts).spin(a);
    $.ajax({
        url: "Resources/Lib/login.php",
        type: "GET",
        data: {
            user: $("#Fullusername").val(),
            passwd: $("#Fullpassword").val(),
            remember: $("#Fullremember").prop("checked")
        },
        dataType: "json",
        success: function(c) {
            b.stop();
            if (c.Result == "Error") {
                $("#Login").show();
                $("#LoginOr").show();
                $("#Register").show();
                $("#FullLoginError").html("Login failed. Please Try Again")
            } else {
                me = c.Result;
                $("#LoginPanel").hide("slide", {
                    direction: "up"
                }, function() {
                    $("#User").html(me.Username);
                    $("#Login").hide();
                    $("#LoginOr").hide();
                    $("#Register").hide();
                    $("#User").show();
                    if (me.Level >= 3) {
                        $(".ModGroup").show()
                    } else {
                        $(".ModGroup").hide()
                    }
                    if (me.Level >= 5) {
                        $(".AdminGroup").show()
                    } else {
                        $(".AdminGroup").hide()
                    }
                    searchString = "";
                    $("#searchBox").val("");
                    titlePage = 0;
                    getTitleList(true)
                })
            }
        }
    })
}

function getMe(a) {
    if (me.length == 0 && a == true) {
        $.ajax({
            url: "Resources/Lib/login.php",
            type: "GET",
            data: {
                user: $("#username").val(),
                passwd: $("#password").val(),
                remember: $("#remember").prop("checked")
            },
            dataType: "json",
            success: function(b) {
                if (b.Result == "Error") {
                    $("#Login").show();
                    $("#LoginOr").show();
                    $("#Register").show();
                    var c = b;
                    $("#LoginPanel").hide("slide", {
                        direction: "up"
                    });
                    $("#LoginPanel").html("");
                    $.ajax({
                        url: "/Resources/Template/FullLogin.html",
                        type: "GET",
                        data: {},
                        dataType: "text",
                        success: function(d) {
                            $("#PaneTitle").html("Activation");
                            $(".MainContent").setTemplate(d);
                            $(".MainContent").processTemplate(c);
                            $("#FullLoginButton").click(function() {
                                getMeFull()
                            });
                            $("#Fullpassword").keypress(function(f) {
                                if (f.which == 13) {
                                    event.preventDefault();
                                    getMeFull()
                                }
                            });
                            $("#FullForgetPassword").click(function() {
                                $.ajax({
                                    url: "/Resources/Template/ForgotPassword.html",
                                    type: "GET",
                                    data: {},
                                    dataType: "text",
                                    success: function(e) {
                                        $("#PaneTitle").html("Activation");
                                        $(".MainContent").setTemplate(e);
                                        $(".MainContent").processTemplate();
                                        $("#ForgotButton").click(function() {
                                            $.ajax({
                                                url: "Resources/Lib/Forgot.php",
                                                type: "GET",
                                                data: {
                                                    email: $("#emailaddress").val()
                                                },
                                                dataType: "json",
                                                success: function(f) {
                                                    $(".ForgotPassword").html('<p class="PageInfo">Email sent with new password</p>')
                                                }
                                            })
                                        })
                                    }
                                })
                            })
                        }
                    })
                } else {
                    me = b.Result;
                    $("#LoginPanel").hide("slide", {
                        direction: "up"
                    }, function() {
                        $("#User").html(me.Username);
                        $("#Login").hide();
                        $("#LoginOr").hide();
                        $("#Register").hide();
                        $("#User").show();
                        if (me.Level >= 3) {
                            $(".ModGroup").show()
                        } else {
                            $(".ModGroup").hide()
                        }
                        if (me.Level >= 5) {
                            $(".AdminGroup").show()
                        } else {
                            $(".AdminGroup").hide()
                        }
                        $("#LoginPanel").html("")
                    })
                }
            }
        })
    } else {
        $.ajax({
            url: "Resources/Lib/login.php",
            type: "GET",
            data: {},
            dataType: "json",
            success: function(b) {
                if (b.Result == "Error") {
                    $("#Login").show();
                    $("#LoginOr").show();
                    $("#Register").show()
                } else {
                    me = b.Result;
                    $("#User").html(me.Username);
                    $("#Login").hide();
                    $("#LoginOr").hide();
                    $("#Register").hide();
                    $("#User").show();
                    if (me.Level >= 3) {
                        $(".ModGroup").show()
                    } else {
                        $(".ModGroup").hide()
                    }
                    if (me.Level >= 5) {
                        $(".AdminGroup").show()
                    } else {
                        $(".AdminGroup").hide()
                    }
                }
            }
        })
    }
}

function getTitleList(b) {
    var c = document.getElementById("MainContent");
    var a = new Spinner(opts).spin(c);
    if (b) {
        titlePage = 0;
        searchString = "";
        titleSort = 0;
        titleSortDirection = 0;
		$.ajax({
			url: "Resources/Lib/Stats.php",
			type: "GET",
			data: {},
			dataType: "json",
			success: function(e) {
				var ttemp = $.createTemplateURL("/Resources/Template/LightMain.html");
				var tdata = $.processTemplateToText(ttemp, e);

				$(".MainContent").html(tdata);
				$("#PaneTitle").html("Title List");

				$(".Stats").html(e.Link)
				$("#searchtext").keyup(function(eData) {
					if (eData.which == 13) {
						window.scrollTo(0, 0);
						var f = this;
						searchString = $("#searchtext").val();
						title.Page = 0;
						getTitleList(false)
					}
                });
			}
		});
	} else {
		$.ajax({
            url: "/Resources/Template/TitlesFull.html",
            type: "GET",
            data: {},
            dataType: "text",
            success: function(d) {
                $("#PaneTitle").html("Title List");
                $(".MainContent").setTemplate(d);
                $(".MainContent").processTemplate();
                $("#TitleList").on("click", ".TabUpdates", function() {
                    $.ajax({
                        url: "Resources/Lib/TitleUpdateInfo.php",
                        type: "GET",
                        data: {
                            titleid: $(this).data("id")
                        },
                        dataType: "json",
                        success: function(g) {
                            var e = $.createTemplateURL("/Resources/Template/TitleUpdateGallery.html");
                            var f = $.processTemplateToText(e, g);
                            $.fancybox.center = function() {};
                            $.fancybox.open({
                                content: f,
                                title: null,
                                type: "html"
                            }, {
                                prevEffect: "none",
                                nextEffect: "none",
                                arrows: false,
                                closeBtn: true,
                                loop: false,
                                autoSize: false,
                                topRatio: 0.5,
                                minWidth: 450,
                                height: "auto",
                                onUpdate: function() {},
                                afterShow: function() {
                                    $(".UpdateDownload").click(function() {
                                        downloadURL("/Resources/Lib/TitleUpdate.php?tuid=" + $(this).data("tuid"))
                                    });
                                    $(".UpdatePush").click(function() {
                                        $.ajax({
                                            url: "Resources/Lib/AddToQ.php",
                                            type: "GET",
                                            data: {
                                                iscover: 0,
                                                isupdate: 1,
                                                itemid: $(this).data("tuid")
                                            },
                                            dataType: "json",
                                            success: function(h) {
                                                if (h.Result == "Already Added") {
                                                    $("#negativemessage").html("Update is already in your Q.");
                                                    $("#dialog-negative").dialog("open")
                                                } else {
                                                    if (h.Result == "Failed") {
                                                        $("negativemessage").html("Update to Add to your Q.");
                                                        $("#dialog-negative").dialog("open")
                                                    } else {
                                                        if (h.Result == "Success") {
                                                            $("#positivemessage").html("Update added to your Q.");
                                                            $("#dialog-positive").dialog("open")
                                                        } else {
                                                            $("#positivemessage").html("Unknow Error.");
                                                            $("#dialog-negative").dialog("open")
                                                        }
                                                    }
                                                }
                                            }
                                        })
                                    })
                                },
                                helpers: {
                                    title: null
                                }
                            })
                        }
                    })
                });
                $("#TitleList").on("click", ".TabCovers", function() {
                    $.ajax({
                        url: "Resources/Lib/CoverInfo.php",
                        type: "GET",
                        data: {
                            titleid: $(this).data("id")
                        },
                        dataType: "json",
                        success: function(h) {
                            var f = 1;
                            var g = h.Covers.length;
                            var i = $.createTemplateURL("/Resources/Template/CoverGallery.html");
                            var e = new Array();
                            $.each(h.Covers, function(k, l) {
                                l.Index = f;
                                f++;
                                l.Total = g;
                                var j = $.processTemplateToText(i, l);
                                e.push({
                                    href: "/Resources/Lib/Cover.php?size=large&cid=" + l.CoverID,
                                    title: j,
                                    type: "image"
                                })
                            });
                            $.fancybox.open(e, {
                                prevEffect: "none",
                                nextEffect: "none",
                                arrows: false,
                                closeBtn: false,
                                aspectRatio: true,
                                topRatio: 0.5,
                                loop: true,
                                onUpdate: function() {
                                    var j = $(".CoverDownloadItem").width();
                                    $(".CoverOfficial").width((j - 250) / 2)
                                },
                                afterShow: function() {
                                    var j = $(".CoverDownloadItem").width();
                                    $(".CoverOfficial").width(j - 50);
                                    if (me.length == 0 || $(this).data("norate") == false) {
                                        $(".CoverRating").jRating({
                                            length: 5,
                                            rateMax: 5,
                                            step: true,
                                            sendRequest: false,
                                            isDisabled: true,
                                            smalStarsPath: "/Resources/Images/stars.png",
                                            bigStarsPath: "/Resources/Images/stars.png"
                                        })
                                    } else {
                                        $(".CoverRating").jRating({
                                            length: 5,
                                            rateMax: 5,
                                            step: true,
                                            sendRequest: true,
                                            isDisabled: false,
                                            phpPath: "/Resources/Lib/jRating.php",
                                            smalStarsPath: "/Resources/Images/stars.png",
                                            bigStarsPath: "/Resources/Images/stars.png",
                                            onSuccess: function(k, l) {},
                                            onError: function(k, l) {}
                                        })
                                    }
                                    $(".CoverDownload").click(function() {
                                        downloadURL("/Resources/Lib/Cover.php?cid=" + $(".CoverDownload").data("cid") + "&tid=" + $(".CoverDownload").data("tid") + "&dl=1&size=large")
                                    });
                                    $(".CoverPush").click(function() {
                                        $.ajax({
                                            url: "Resources/Lib/AddToQ.php",
                                            type: "GET",
                                            data: {
                                                iscover: 1,
                                                isupdate: 0,
                                                itemid: $(".CoverPush").data("cid")
                                            },
                                            dataType: "json",
                                            success: function(k) {
                                                if (k.Result == "Already Added") {
                                                    $("#negativemessage").html("Cover is already in your Q.");
                                                    $("#dialog-negative").dialog("open")
                                                } else {
                                                    if (k.Result == "Failed") {
                                                        $("#negativemessage").html("Failed to Add to your Q.");
                                                        $("#dialog-negative").dialog("open")
                                                    } else {
                                                        if (k.Result == "Success") {
                                                            $("#positivemessage").html("Cover added to your Q.");
                                                            $("#dialog-positive").dialog("open")
                                                        } else {
                                                            $("#positivemessage").html("Unknow Error.");
                                                            $("#dialog-negative").dialog("open")
                                                        }
                                                    }
                                                }
                                            }
                                        })
                                    })
                                },
                                helpers: {
                                    title: {
                                        type: "inside"
                                    },
                                    buttons: {}
                                }
                            })
                        }
                    })
                });
                $("#TitleList").on("click", ".TabLink", function() {
                    var e = $(this);
                    $.ajax({
                        url: "Resources/Lib/LinkInfo.php",
                        type: "GET",
                        data: {
                            titleid: $(this).data("id")
                        },
                        dataType: "json",
                        success: function(g) {
                            var h = $.createTemplateURL("/Resources/Template/LinkInfoItem.html");
                            var f = $.createTemplateURL("/Resources/Template/LinkUserInfo.html");
                            var j = new Array();
                            $.each(g.Rooms, function(l, m) {
                                if (m.RoomID == me.LocationID) {
                                    m.InRoom = true
                                } else {
                                    m.InRoom = false
                                }
                                m.me = me;
                                var k = $.processTemplateToText(h, m);
                                j.push({
                                    content: k,
                                    title: "Room 1 of " + g.Rooms.length,
                                    type: "html"
                                })
                            });
                            var i = 0;
                            $.fancybox.open(j, {
                                prevEffect: "none",
                                nextEffect: "none",
                                arrows: false,
                                closeBtn: false,
                                loop: true,
                                index: LinkIndex,
                                autoSize: true,
                                topRatio: 0.15,
                                minWidth: 575,
                                height: "auto",
                                afterClose: function() {
                                    LinkIndex = 0
                                },
                                afterLoad: function(l, k) {
                                    i = l.index
                                },
                                onUpdate: function() {},
                                beforeShow: function() {
                                    this.title = "Room " + (this.index + 1) + " of " + this.group.length
                                },
                                afterShow: function() {
                                    $(".RoomJoin").click(function() {
                                        var o = $(this).data("room");
                                        var n = $(this).data("roomname");
                                        if ($(this).data("private") == 1) {
                                            var m = 0;
                                            var k = new Array();
                                            var p = $.createTemplateURL("/Resources/Template/JoinPrivate.html");
                                            var l = $.processTemplateToText(p, {
                                                RoomName: n,
                                                RoomID: o
                                            });
                                            $.fancybox.open({
                                                content: l,
                                                title: n,
                                                type: "html"
                                            }, {
                                                prevEffect: "none",
                                                nextEffect: "none",
                                                arrows: false,
                                                closeBtn: false,
                                                loop: false,
                                                autoSize: true,
                                                topRatio: 0.15,
                                                minWidth: 575,
                                                height: "auto",
                                                onUpdate: function() {},
                                                beforeShow: function() {},
                                                afterShow: function() {
                                                    $("#CancelRoom").click(function() {
                                                        LinkIndex = i;
                                                        e.click()
                                                    });
                                                    $(".pcBtn").click(function() {
                                                        if (m < maxPassCode) {
                                                            m++;
                                                            k.push($(this).data("val"));
                                                            $("#passBtn").empty();
                                                            var q = "";
                                                            $.each(k, function(r, t) {
                                                                if (t < 10) {
                                                                    q += "0" + t.toString()
                                                                } else {
                                                                    q += t.toString()
                                                                }
                                                                var s = PassCode(t);
                                                                $("#passBtn").append(s)
                                                            });
                                                            $("#password").val(parseInt(q, 16))
                                                        }
                                                    });
                                                    $(".passButtons").click(function() {
                                                        if (m > 0) {
                                                            m--;
                                                            k.pop();
                                                            $("#passBtn").empty();
                                                            var q = "";
                                                            $.each(k, function(r, t) {
                                                                if (t < 10) {
                                                                    q += "0" + t.toString()
                                                                } else {
                                                                    q += t.toString()
                                                                }
                                                                var s = PassCode(t);
                                                                $("#passBtn").append(s)
                                                            });
                                                            $("#password").val(parseInt(q, 16))
                                                        }
                                                    });
                                                    $("#JoinRoom").click(function() {
                                                        $.ajax({
                                                            url: "Resources/Lib/LinkJoinRoom.php",
                                                            type: "GET",
                                                            data: {
                                                                room: o,
                                                                pass: $("#password").val()
                                                            },
                                                            dataType: "json",
                                                            success: function(q) {
                                                                if (q.Result == "Success") {
                                                                    $("#positivemessage").html("Successfully Joined Room.");
                                                                    $("#dialog-positive").dialog("open");
                                                                    $("#dialog-positive").on("dialogclose", function(r, s) {
                                                                        $("#dialog-positive").on("dialogclose", function(t, u) {});
                                                                        LinkIndex = 0;
                                                                        getMe();
                                                                        e.click()
                                                                    })
                                                                } else {
                                                                    $("#negativemessage").html("Failed to Join Room.");
                                                                    $("#dialog-negative").dialog("open")
                                                                }
                                                            }
                                                        })
                                                    })
                                                }
                                            })
                                        } else {
                                            $.ajax({
                                                url: "Resources/Lib/LinkJoinRoom.php",
                                                type: "GET",
                                                data: {
                                                    room: o
                                                },
                                                dataType: "json",
                                                success: function(q) {
                                                    if (q.Result == "Success") {
                                                        $("#positivemessage").html("Successfully Joined Room.");
                                                        $("#dialog-positive").dialog("open");
                                                        $("#dialog-positive").on("dialogclose", function(r, s) {
                                                            $("#dialog-positive").on("dialogclose", function(t, u) {});
                                                            LinkIndex = 0;
                                                            getMe();
                                                            e.click()
                                                        })
                                                    } else {
                                                        $("#negativemessage").html("Failed to Join Room.");
                                                        $("#dialog-negative").dialog("open")
                                                    }
                                                }
                                            })
                                        }
                                    });
                                    $(".RoomPart").click(function() {
                                        var k = $(this).data("room");
                                        $.ajax({
                                            url: "Resources/Lib/LinkPartRoom.php",
                                            type: "GET",
                                            data: {
                                                room: k
                                            },
                                            dataType: "json",
                                            success: function(l) {
                                                if (l.Result == "Success") {
                                                    $("#positivemessage").html("Successfully Left Room.");
                                                    $("#dialog-positive").dialog("open");
                                                    $("#dialog-positive").on("dialogclose", function(n, m) {
                                                        $("#dialog-positive").on("dialogclose", function(o, p) {});
                                                        LinkIndex = 0;
                                                        getMe();
                                                        e.click()
                                                    })
                                                } else {
                                                    $("#negativemessage").html("Failed to Leave Room.");
                                                    $("#dialog-negative").dialog("open")
                                                }
                                            }
                                        })
                                    });
                                    $(".UserKick").click(function() {
                                        var l = $(this).data("id");
                                        var k = $(this).data("room");
                                        $("#User" + l).remove();
                                        $.ajax({
                                            url: "Resources/Lib/LinkKickUser.php",
                                            type: "GET",
                                            data: {
                                                room: k,
                                                id: l
                                            },
                                            dataType: "json",
                                            success: function(m) {
                                                LinkIndex = i;
                                                e.click()
                                            }
                                        })
                                    });
                                    $(".UserLeader").click(function() {
                                        var k = $(this).data("id");
                                        var l = $(this).data("room");
                                        $("#LeaderIcon").remove();
                                        $("#User" + k).prepend('<img class="leadericonimage" src="/Resources/Images/user_leader.png" title="User is leader of room.">');
                                        $.ajax({
                                            url: "Resources/Lib/LinkSetLeader.php",
                                            type: "GET",
                                            data: {
                                                room: l,
                                                id: k
                                            },
                                            dataType: "json",
                                            success: function(m) {
                                                LinkIndex = i;
                                                e.click()
                                            }
                                        })
                                    });
                                    $(".UserFriend").click(function() {
                                        var k = $(this).data("id");
                                        $.ajax({
                                            url: "Resources/Lib/SetRelation.php",
                                            type: "GET",
                                            data: {
                                                target: k,
                                                Type: 1
                                            },
                                            dataType: "json",
                                            success: function(l) {
                                                LinkIndex = i;
                                                e.click()
                                            }
                                        })
                                    });
                                    $(".UserBlock").click(function() {
                                        var k = $(this).data("id");
                                        $.ajax({
                                            url: "Resources/Lib/SetRelation.php",
                                            type: "GET",
                                            data: {
                                                target: k,
                                                Type: 2
                                            },
                                            dataType: "json",
                                            success: function(l) {
                                                LinkIndex = i;
                                                e.click()
                                            }
                                        })
                                    })
                                },
                                helpers: {
                                    buttons: {}
                                }
                            })
                        }
                    })
                });
                $("#TitleList").on("click", ".TitlePage", function() {
                    window.scrollTo(0, 0);
                    title.Page = $(this).data("id");
                    if (title.Page < 0) {
                        title.Page = 0
                    }
                    if (title.Page > title.Pages) {
                        title.Page = title.Pages - 1
                    }
                    getTitleList(false)
                });
                $("#searchtext").keyup(function(eData) {
					if (eData.which == 13) {
						window.scrollTo(0, 0);
						var f = this;
						searchString = $("#searchtext").val();
						title.Page = 0;
						getTitleList(false)
					}
                });
                $("#TitleList").on("click", ".TitleLast", function() {
                    window.scrollTo(0, 0);
                    title.Page = title.Pages - 1;
                    getTitleList(false)
                });
                $("#TitleList").on("click", ".TitleNext", function() {
                    window.scrollTo(0, 0);
                    title.Page++;
                    if (title.Page > title.Pages) {
                        title.Page = title.Pages - 1
                    }
                    getTitleList(false)
                });
                $("#TitleList").on("click", ".TitleFirst", function() {
                    title.Page = 0;
                    getTitleList(false)
                });
                $("#TitleList").on("click", ".TitlePrev", function() {
                    window.scrollTo(0, 0);
                    title.Page--;
                    if (title.Page < 0) {
                        title.Page = 0
                    }
                    getTitleList(false)
                })
            }
        })

		$.ajax({
			url: "Resources/Lib/TitleList.php",
			type: "GET",
			data: {
				page: title.Page,
				count: title.Increment,
				search: searchString,
				sort: title.Sort,
				direction: title.SortDirection,
				category: title.Category,
				filter: title.Filter
			},
			dataType: "json",
			success: function(d) {
				title.Total = d.Count;
				title.Pages = d.Pages;
				d.me = me;
				d.searchText = searchString;
				var e = $.createTemplateURL("/Resources/Template/TitleListItems.html");
				var g = $.createTemplateURL("/Resources/Template/TitleListPaging.html");
				var f = $.processTemplateToText(e, d);
				var h = $.processTemplateToText(g, d);
				$("#ListBox").html(f);
				$(".TitlePages").html(h);
				$(".AdminEdit").click(function() {
					var i = document.getElementById("MainContent");
					var k = new Spinner(opts).spin(i);
					var j = $(this).data("tid");
					$.ajax({
						url: "Resources/Lib/Title.php",
						type: "GET",
						data: {
							tid: j
						},
						dataType: "json",
						success: function(n) {
							k.stop();
							var m = $.createTemplateURL("/Resources/Template/EditTitle.html");
							var l = $.processTemplateToText(m, n);
							$(".MainContent").html(l);
							$.each(n.Covers, function(o, p) {
								$("#" + p.CoverID).on("click", function() {
									var r = $(this).data("id");
									var q = $(this).data("uploader");
									$.fancybox.open({
										href: "/Resources/Lib/Cover.php?cid=" + r + "&size=large",
										title: "<div class='DeleteCoverItem'>ID: " + r + " Uploader: " + q + " <div class='page dark NiceButton DeleteCoverButton' id='deleteCover' data-id='" + r + "' >Delete Cover</div></div>",
										type: "image"
									}, {
										helpers: {
											title: {
												type: "inside"
											}
										},
										afterShow: function() {
											$("#deleteCover").click(function() {
												var s = document.getElementById("MainContent");
												var t = new Spinner(opts).spin(s);
												$.ajax({
													url: "Resources/Lib/DeleteCover.php",
													type: "GET",
													data: {
														cid: r
													},
													dataType: "json",
													success: function(u) {
														console.log(u);
														t.stop();
														$.fancybox.close();
														if (u.Result == "Success") {
															$("#" + r).remove()
														}
													}
												})
											})
										}
									})
								})
							});
							$(".deleteUpdate").on("click", function() {
								var p = $(this).data("id");
								var o = document.getElementById("MainContent");
								var q = new Spinner(opts).spin(o);
								$.ajax({
									url: "Resources/Lib/DeleteTitleUpdate.php",
									type: "GET",
									data: {
										tuid: p
									},
									dataType: "json",
									success: function(r) {
										console.log(r);
										q.stop();
										if (r.Result == "Success") {
											console.log("Removing DIV");
											$("#" + p).remove()
										}
									}
								})
							});
							$("#AddLobby").on('click', function() {
								var p = document.getElementById("MainContent");
								var q = new Spinner(opts).spin(p);
								var id = $(this).data("id");
								var name = $(this).data("name");
								$.ajax({
									url: "Resources/Lib/AddLobby.php",
									type: "GET",
									data: {
										tid: id,
										name: name
									},
									dataType: "json",
									success: function(r) {
										$('#editlink').prop('checked', true);
										q.stop()
									}
								})
							});
							$("#editupdate").on("click", function() {
								var p = document.getElementById("MainContent");
								var q = new Spinner(opts).spin(p);
								var o = 0;
								if ($("#editlink").is(":checked")) {
									o = 1
								}
								$.ajax({
									url: "Resources/Lib/EditTitleInfo.php",
									type: "GET",
									data: {
										tid: $("#edittitleid").val(),
										name: $("#edittitle").val(),
										otid: $("#origtitleid").val(),
										ttype: $("#edittype").find(":selected").val(),
										link: o
									},
									dataType: "json",
									success: function(r) {
										console.log(r);
										q.stop()
									}
								})
							});
							$("#editcancel").on("click", function() {
								getTitleList(true)
							})
						}
					})
				});
				$("#TitleFilter").click(function() {
					var i = $.createTemplateURL("/Resources/Template/TitleListFilter.html");
					var j = $.processTemplateToText(i, title);
					$.fancybox.open({
						content: j,
						title: null,
						type: "html"
					}, {
						prevEffect: "none",
						nextEffect: "none",
						arrows: false,
						closeBtn: false,
						loop: false,
						autoSize: false,
						autoCenter: true,
						topRatio: 0.25,
						minWidth: 450,
						height: "auto",
						onUpdate: function() {},
						afterShow: function() {
							$("#SortCancel").click(function() {
								$.fancybox.close()
							});
							$("#SortApply").click(function() {
								title.Filter = $('input:radio[name="filter"]:checked').val();
								title.Category = $('input:radio[name="category"]:checked').val();
								title.Sort = $("#TitleSortChoice").val();
								title.SortDirection = $("#TitleSortDirection").val();
								title.Page = 0;
								searchString = "";
								$.fancybox.close();
								getTitleList(false)
							})
						},
						helpers: {
							title: null
						}
					})
				});
				a.stop()
			}
		})
    }

}

function downloadURL(b) {
    var a = "hiddenDownloader",
        c = document.getElementById(a);
    if (c === null) {
        c = document.createElement("iframe");
        c.id = a;
        c.style.display = "none";
        document.body.appendChild(c)
    }
    c.src = b
}

function getUrlVars() {
    var b = {};
    var a = window.location.href.replace(/[?&]+([^=&]+)=([^&]*)/gi, function(e, c, d) {
        b[c] = d
    });
    return b
}

function PassCode(a) {
    switch (a) {
        case 2:
            return "<img src='/Resources/Images/Passcode/X-Button_full.png' />";
            break;
        case 3:
            return "<img src='/Resources/Images/Passcode/Y-Button_full.png' />";
            break;
        case 4:
            return "<img src='/Resources/Images/Passcode/rb_32x.png' />";
            break;
        case 5:
            return "<img src='/Resources/Images/Passcode/lb_32x.png' />";
            break;
        case 6:
            return "<img src='/Resources/Images/Passcode/lt_32x.png' />";
            break;
        case 7:
            return "<img src='/Resources/Images/Passcode/rt_32x.png' />";
            break;
        case 10:
            return "<img src='/Resources/Images/Passcode/up_d.png' />";
            break;
        case 11:
            return "<img src='/Resources/Images/Passcode/down_d.png' />";
            break;
        case 12:
            return "<img src='/Resources/Images/Passcode/left_d.png' />";
            break;
        case 13:
            return "<img src='/Resources/Images/Passcode/right_d.png' />";
            break
    }
    return code
};
