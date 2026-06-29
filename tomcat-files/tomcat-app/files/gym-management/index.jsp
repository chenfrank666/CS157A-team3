<%@ page import="javax.naming.Context,javax.naming.InitialContext,javax.sql.DataSource,java.sql.*,java.security.SecureRandom,java.util.Base64"%>
<html>
<head>
    <title>Gym Management System</title>
    <style>
     h1 {
	 text-align: center;
     }
     .login-box {
	 display: grid;
	 grid-template-columns: auto auto;
	 background-color: #e0e0e0;
	 color: black;
	 padding: 10px;
     }
     .login-box-left {
	 background-color: #e0e0e0;
	 color: black;
	 border: 1px solid #e0e0e0;
	 padding: 5px;
	 text-align: left;
     }
     .login-box-right {
	 background-color: #e0e0e0;
	 color: black;
	 border: 1px solid #e0e0e0;
	 padding: 5px;
	 text-align: right;
     }
    </style>
</head>
<body>
    <h1>Gym Management System</h1>
    <%!
    /* Functions for cookie handling */
    private static String makeCookie(int type)
    {
	SecureRandom random = new SecureRandom();
        byte[] cookie_data = new byte[17];
	byte[] cookie_bin = new byte[18];
        random.nextBytes(cookie_data);
        System.arraycopy(cookie_data, 0, cookie_bin, 1, 17);
	cookie_bin[0] = (byte) type;
        return Base64.getEncoder().encodeToString(cookie_bin);
    }

    private static int getCookieUserType(String cookie)
    {
	byte[] cookie_bin = Base64.getDecoder().decode(cookie);
        if (cookie_bin.length < 18)
        return -1;
	else
	return (int) cookie_bin[0];
    }
    %>
    <%
    /* Login form processing */
    String login_user = null;
    String login_password = null;
    int log_out = 0;
    if (request.getMethod().equals("POST")) {
	login_user = request.getParameter("login");
	login_password = request.getParameter("password");
	if (login_user == null)	log_out = 1;
    } /* Non-POST requests will have those values set to null */

    /* Database connection */
    java.sql.Connection con = null;
    try {
	Context initContext = new InitialContext();
	Context envContext = (Context) initContext.lookup("java:comp/env");
	DataSource ds = (DataSource) envContext.lookup("jdbc/GymDB");
	con = ds.getConnection();
    } catch(SQLException e) {
        out.println("Database connection error<br />");
    }

    /* Authentication with a cookie */
    String auth_cookie = null;
    String auth_user_fname = null;
    String auth_user_lname = null;
    int auth_user_id = -1;
    int auth_user_type = -1;
    Cookie[] cookies = request.getCookies();
    if (cookies != null) {
	for (Cookie cookie : cookies) {
	    if (cookie.getName().equals("gym_auth")) {
		auth_cookie = cookie.getValue();
	    }
	}
    }
    if (auth_cookie != null) {
	auth_user_type = getCookieUserType(auth_cookie);
	if ((auth_user_type < 0) || (auth_user_type > 1)) {
	    auth_cookie = null;
	    auth_user_type = -1;
	}
    }
    if (con == null) {
	auth_cookie = null;
	auth_user_type = -1;
    }
    if (auth_cookie != null) {
	if (auth_user_type == 0) {
	    /* Employee */
	    PreparedStatement cookie_auth_stmt = con.prepareStatement(
"SELECT user_id, first_name, last_name FROM employees WHERE user_cookie = ?");
	    cookie_auth_stmt.setString(1, auth_cookie);
	    try {
		ResultSet cookie_auth_result = cookie_auth_stmt.executeQuery();
		if (cookie_auth_result.next()) {
		    auth_user_id = cookie_auth_result.getInt(1);
		    auth_user_fname = cookie_auth_result.getString(2);
		    auth_user_lname = cookie_auth_result.getString(3);
		} else {
		    auth_cookie = null;
		    auth_user_type = -1;
		}
		cookie_auth_result.close();
	    } catch(SQLException e) {
		auth_cookie = null;
		auth_user_type = -1;
	    }
	    cookie_auth_stmt.close();
	} else {
	    /* Member */
	    PreparedStatement cookie_auth_stmt = con.prepareStatement(
"SELECT user_id, first_name, last_name FROM members WHERE user_cookie = ?");
	    cookie_auth_stmt.setString(1, auth_cookie);
	    try {
		ResultSet cookie_auth_result = cookie_auth_stmt.executeQuery();
		if (cookie_auth_result.next()) {
		    auth_user_id = cookie_auth_result.getInt(1);
		    auth_user_fname = cookie_auth_result.getString(2);
		    auth_user_lname = cookie_auth_result.getString(3);
		} else {
		    auth_cookie = null;
		    auth_user_type = -1;
		}
		cookie_auth_result.close();
	    } catch(SQLException e) {
		auth_cookie = null;
		auth_user_type = -1;
	    }
	    cookie_auth_stmt.close();
	}
    }

    /* New login authentication */
    int login_user_type = -1;
    int login_user_id = -1;
    if ((con != null) && (login_user!= null) && (login_password != null)) {
	PreparedStatement user_stmt = con.prepareStatement(
"SELECT user_id, user_type, user_password FROM users WHERE user_name = ?");
	user_stmt.setString(1, login_user);
	try {
	    ResultSet user_result = user_stmt.executeQuery();
	    if (user_result.next()) {
		if (user_result.getString(3).equals(login_password)) {
		    /* Login successful */
		    login_user_id = user_result.getInt(1);
		    login_user_type = user_result.getInt(2);
		    if (login_user_type == 0) {
			/* Employee */
			PreparedStatement cookie_stmt = con.prepareStatement(
"UPDATE employees SET user_cookie = ? WHERE user_id = ?");
			cookie_stmt.setInt(2, login_user_id);
			int cookie_result = 0;
			do {
			    String login_cookie = makeCookie(login_user_type);
			    cookie_stmt.setString(1, login_cookie);
			    try {
				cookie_result =	cookie_stmt.executeUpdate();
			    } catch(SQLException e) {
				cookie_result = -1;
			    }
			    if (cookie_result == 1) {
				response.addCookie(
				    new Cookie("gym_auth", login_cookie));
				response.sendRedirect(
				    "/tomcat-app/gym-management/");
			    }
			} while (cookie_result == 0);
			cookie_stmt.close();
		    } else {
			if (login_user_type == 1) {
			    /* Member */
			    PreparedStatement cookie_stmt = con.prepareStatement(
"UPDATE members SET user_cookie = ? WHERE user_id = ?");
			    cookie_stmt.setInt(2, login_user_id);
			    int cookie_result = 0;
			    do {
				String login_cookie = makeCookie(login_user_type);
				cookie_stmt.setString(1, login_cookie);
				try {
				    cookie_result = cookie_stmt.executeUpdate();
				} catch(SQLException e) {
				    cookie_result = -1;
				}
				if (cookie_result == 1) {
				    response.addCookie(
					new Cookie("gym_auth", login_cookie));
				    response.sendRedirect(
					"/tomcat-app/gym-management/");
				}
			    } while (cookie_result == 0);
			    cookie_stmt.close();
			} else {
			    login_user_id = -1;
			    login_user_type = -1;
			}
		    }
		}
	    }
	    user_result.close();
	} catch(SQLException e) {
	}
	user_stmt.close();
	/* Don't use those values after this point */
	login_user = null;
	login_password = null;
    }

    /* Log out handling */
    if (log_out == 1) {
	if ((con != null) && (auth_user_id >= 0)
	    && (auth_user_type >= 0) && (auth_user_type <= 1)) {
	    if (auth_user_type == 0) {
		PreparedStatement cookie_stmt = con.prepareStatement(
"UPDATE employees SET user_cookie = '' WHERE user_id = ?");
		cookie_stmt.setInt(1, auth_user_id);
		try {
		    cookie_stmt.executeUpdate();
		} catch(SQLException e) {
		}
		cookie_stmt.close();
	    } else {
		PreparedStatement cookie_stmt = con.prepareStatement(
"UPDATE members SET user_cookie = '' WHERE user_id = ?");
		cookie_stmt.setInt(1, auth_user_id);
		try {
		    cookie_stmt.executeUpdate();
		} catch(SQLException e) {
		}
		cookie_stmt.close();
	    }
	}
	response.addCookie(new Cookie("gym_auth", ""));
	auth_user_id = -1;
	auth_user_type = -1;
	auth_user_fname = null;
	auth_user_lname = null;
    }
    %>
    <div>
	<%
	if (auth_user_id < 0) {
	%>
	<form class="login-box"
	      action="/tomcat-app/gym-management/" method="post">
	    <div class="login-box-right"><label>Login</label></div>
	    <div class="login-box-left"><input name="login"
					       type="text" /></div>
	    <div class="login-box-right"><label>Password</label></div>
	    <div class="login-box-left"><input name="password"
					       type="password" /></div>
	    <div class="login-box-right"><input
					     type="submit"
					     value="Login" /></div>
	</form>
	<%
	} else {
	%>
	<form class="login-box"
	      action="/tomcat-app/gym-management/" method="post">
	    <div class="login-box-right"><input
					     type="submit"
					     value="Log out" /></div>
	</form>
	<%
	}
	%>
    </div>
    <div>
	<%
	if ((login_user_id >= 0) || (auth_user_id >= 0)) {
	    out.println("Authenticated user type:" + auth_user_type
		+ " Authenticated user ID:" + auth_user_id
		+ "<br/>");
	}

	if ((con != null) && (auth_user_type >= 0)) {
	    if (auth_user_type == 0) {
		out.println("Initial entries in table \"employees\": <br/>");
		Statement stmt = con.createStatement();
		ResultSet rs = stmt.executeQuery("SELECT * FROM employees");
		while (rs.next()) {
		    out.println("" + rs.getInt(1) + " "
			+ rs.getString(2) + " "
			+ rs.getString(3) + "<br/>");
		}
		rs.close();
		stmt.close();
	    } else {
		out.println("Initial entries in table \"members\": <br/>");
		Statement stmt = con.createStatement();
		ResultSet rs = stmt.executeQuery("SELECT * FROM members");
		while (rs.next()) {
		    out.println("" + rs.getInt(1) + " "
			+ rs.getString(2) + " "
			+ rs.getString(3) + "<br/>");
		}
		rs.close();
		stmt.close();
	    }
	}
	%>
    </div>
    <%
    if (con != null) con.close();
    %>
</body>
</html>
