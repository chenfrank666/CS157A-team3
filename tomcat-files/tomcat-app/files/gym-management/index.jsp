<%@ page import="java.security.SecureRandom,java.util.Base64"%>
<html>
<head>
    <meta charset="UTF-8" />
    <title>Gym Management System</title>
    <link rel="stylesheet" href="style.css" />
</head>
<body>
    <%!
    /* Generates a fresh authentication cookie; the first byte is the user type */
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
    %>
    <%@ include file="/WEB-INF/includes/auth-check.jspf" %>
    <%
    /* New login authentication */
    boolean login_attempted = (login_user != null) && (login_password != null);
    int login_user_type = -1;
    int login_user_id = -1;
    if (login_attempted && (con != null)) {
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
		    java.sql.Timestamp expiry = new java.sql.Timestamp(
			System.currentTimeMillis() + 30L * 24 * 60 * 60 * 1000);
		    PreparedStatement cookie_stmt = con.prepareStatement(
"UPDATE users SET cookie_value = ?, cookie_expiration_time = ? WHERE user_id = ?");
		    int cookie_result = 0;
		    do {
			String login_cookie = makeCookie(login_user_type);
			cookie_stmt.setString(1, login_cookie);
			cookie_stmt.setTimestamp(2, expiry);
			cookie_stmt.setInt(3, login_user_id);
			try {
			    cookie_result = cookie_stmt.executeUpdate();
			} catch(SQLException e) {
			    cookie_result = -1;
			}
			if (cookie_result == 1) {
			    Cookie auth = new Cookie("gym_auth", login_cookie);
			    auth.setPath("/tomcat-app/gym-management/");
			    auth.setMaxAge(30 * 24 * 60 * 60);
			    response.addCookie(auth);
			    response.sendRedirect("/tomcat-app/gym-management/");
			}
		    } while (cookie_result == 0);
		    cookie_stmt.close();
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
    boolean login_failed = login_attempted && (login_user_id < 0);

    /* Log out handling */
    if (log_out == 1) {
	if ((con != null) && (auth_user_id >= 0)) {
	    PreparedStatement cookie_stmt = con.prepareStatement(
"UPDATE users SET cookie_value = NULL, cookie_expiration_time = NULL WHERE user_id = ?");
	    cookie_stmt.setInt(1, auth_user_id);
	    try {
		cookie_stmt.executeUpdate();
	    } catch(SQLException e) {
	    }
	    cookie_stmt.close();
	}
	Cookie auth = new Cookie("gym_auth", "");
	auth.setPath("/tomcat-app/gym-management/");
	auth.setMaxAge(0);
	response.addCookie(auth);
	auth_user_id = -1;
	auth_user_type = -1;
	auth_user_fname = null;
	auth_user_lname = null;
	auth_coach_flag = 0;
	auth_admin_flag = 0;
	auth_member_active = 0;
    }

    boolean can_view_schedule = (auth_user_type == 1)
	|| (auth_user_type == 0 && (auth_coach_flag == 1 || auth_admin_flag == 1));
    String active_page = "home";
    %>
    <%@ include file="/WEB-INF/includes/navbar.jspf" %>

    <% if (auth_user_id < 0) { %>
    <div class="login-shell">
	<div class="card container-narrow">
	    <div class="hero">
		<h1>Gym Management System</h1>
		<p class="subtitle">Sign in to view your schedule and manage your groups.</p>
	    </div>
	    <% if (login_failed) { %>
	    <div class="message message-error">Incorrect username or password.</div>
	    <% } %>
	    <form action="/tomcat-app/gym-management/" method="post">
		<div class="form-row">
		    <label for="login">Username</label>
		    <input id="login" name="login" type="text" autocomplete="username" />
		</div>
		<div class="form-row">
		    <label for="password">Password</label>
		    <input id="password" name="password" type="password" autocomplete="current-password" />
		</div>
		<button type="submit" class="btn" style="width: 100%;">Log in</button>
	    </form>
	</div>
    </div>
    <% } else { %>
    <main class="container">
	<div class="card">
	    <h1>Welcome back, <%= auth_user_fname %>!</h1>
	    <p class="subtitle">
		<% if (auth_user_type == 1) { %>
		Here's quick access to your classes and groups.
		<% } else if (auth_admin_flag == 1) { %>
		You have administrator access to the full schedule and group roster.
		<% } else if (auth_coach_flag == 1) { %>
		Here's quick access to the classes you coach.
		<% } else { %>
		Here's quick access to gym groups.
		<% } %>
	    </p>
	    <div class="quick-links">
		<% if (can_view_schedule) { %>
		<a class="btn" href="schedule.jsp">View schedule</a>
		<% } %>
		<a class="btn btn-secondary" href="groups.jsp">Browse groups</a>
	    </div>
	</div>
    </main>
    <% } %>
    <%
    if (con != null) con.close();
    %>
</body>
</html>
