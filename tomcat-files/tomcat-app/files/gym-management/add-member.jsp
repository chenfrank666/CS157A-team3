<%@ page import="java.sql.*, javax.naming.*, javax.sql.DataSource" %>
<%@ include file="/WEB-INF/includes/auth-check.jspf" %>
<%
    if (auth_admin_flag != 1) {
        response.sendRedirect("/tomcat-app/gym-management/");
        return;
    }

    String active_page = "add-member";
%>
<!DOCTYPE html>
<html>
<head>
    <title>Add Member - Gym Management System</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <%@ include file="/WEB-INF/includes/navbar.jspf" %>
    <% if (request.getMethod().equals("POST") && (con != null)) {
	int err = 1;
	String username = request.getParameter("username");
	String password1 = request.getParameter("password1");
	String password2 = request.getParameter("password2");
	String fname = request.getParameter("fname");
	String lname = request.getParameter("lname");
	String goals = request.getParameter("goals");
	String health_notes = request.getParameter("health_notes");
	String active_flag = request.getParameter("active_flag");

	if (password1.equals(password2) && !password1.equals("")) {
	    java.util.Date now_util = new java.util.Date();
	    java.sql.Date now = new java.sql.Date(now_util.getTime());

	    con.setAutoCommit(false);
	    try {
		String getid_sql = "SELECT MAX(user_id) FROM users";
		Statement getid_stmt = con.createStatement();
		ResultSet getid_res = getid_stmt.executeQuery(getid_sql);
		int new_user_id = 0;
		if (getid_res.next()) {
		    new_user_id = getid_res.getInt(1) + 1;
		    getid_res.close();

		    // Insert active_flag directly into the users table
		    String insert_user_sql =
		    "INSERT INTO users (user_name, user_password, user_id, "
		    + "user_type, "
		    + "first_name, last_name, start_date, end_date, "
		    + "cookie_value, cookie_expiration_time, active_flag) "
		    + "VALUES(?, ?, ?, 1, ?, ?, ?, null, null, null, ?)";

		    PreparedStatement insert_user_stmt =
		    con.prepareStatement(insert_user_sql);
		    insert_user_stmt.setString(1, username);
		    insert_user_stmt.setString(2, password1);
		    insert_user_stmt.setInt(3, new_user_id);
		    insert_user_stmt.setString(4, fname);
		    insert_user_stmt.setString(5, lname);
		    insert_user_stmt.setDate(6, now);
		    insert_user_stmt.setInt(7, (active_flag != null) ? 1 : 0);
		    insert_user_stmt.executeUpdate();
		    insert_user_stmt.close();

		    // Removed active_flag from members insert query
		    String insert_memb_sql =
		    "INSERT INTO members (user_id, cookie_expire, "
		    + "health_notes, goals, start_date, end_date) "
		    + "VALUES(?, null, ?, ?, ?, null)";
		    PreparedStatement insert_memb_stmt =
		    con.prepareStatement(insert_memb_sql);
		    insert_memb_stmt.setInt(1, new_user_id);
		    insert_memb_stmt.setString(2, health_notes);
		    insert_memb_stmt.setString(3, goals);
		    insert_memb_stmt.setDate(4, now);
		    insert_memb_stmt.executeUpdate();
		    insert_memb_stmt.close();
    %>
    <div class="card container-input">
	<form action="add-member.jsp" method="get">
	    <div class="form-row">
		<label>Member added successfully</label>
	    </div>
	    <div class="form-row">
		<label class="result">Username:</label>
		<label class="result_value"><%= username %></label>
	    </div>
	    <div class="form-row">
		<label class="result">First name:</label>
		<label class="result_value"><%= fname %></label>
	    </div>
	    <div class="form-row">
		<label class="result">Last name:</label>
		<label class="result_value"><%= lname %></label>
	    </div>
	    <div class="form-row">
		<label class="result">Health notes:</label>
		<textarea id="health_notes" name="health_notes" readonly rows="3"><%= health_notes %></textarea>
	    </div>
	    <div class="form-row">
		<label class="result">Goals:</label>
		<textarea id="goals" name="goals" readonly rows="3"><%= goals %></textarea>
	    </div>
	    <div class="form-row">
		<label class="result"><% if (active_flag != null) out.print("Active"); else out.print("INACTIVE"); %></label>
	    </div>
	    <button type="submit" class="btn" style="width: 100%;">Add another member</button>
	</form>
    </div>
    <%
		    con.commit();
		    err = 0;
		} else {
	            getid_stmt.close();
		    con.rollback();
		}
	    } catch (SQLException e) {
    %>
	<div class="card container-input">
	    <form action="add-member.jsp" method="post">
		<div class="form-row">
		    <label>Invalid entry, change name and try again</label>
		</div>
		<div class="form-row">
		    <label>Username</label>
		    <input id="username" name="username" type="text" value="<%= username %>" />
		</div>
		<div class="form-row">
		    <label>Password</label>
		    <input id="password1" name="password1" type="password" value="<%= password1 %>" />
		</div>
		<div class="form-row">
		    <label>Password Again</label>
		    <input id="password2" name="password2" type="password" value="<%= password2 %>" />
		</div>
		<div class="form-row">
		    <label>First name</label>
		    <input id="fname" name="fname" type="text" value="<%= fname %>" />
		    <label>Last name</label>
		    <input id="lname" name="lname" type="text" value="<%= lname %>" />
		</div>
		<div class="form-row">
		    <label>Health notes:</label>
		    <textarea id="health_notes" name="health_notes" rows="3"><%= health_notes %></textarea>
		</div>
		<div class="form-row">
		    <label>Goals:</label>
		    <textarea id="goals" name="goals" rows="3"><%= goals %></textarea>
		</div>
		<div class="form-row">
		    <input id="active_flag" name="active_flag" type="checkbox" value="active_flag" <% if (active_flag != null) out.print("checked"); %> />
		    <label class="check">Active</label>
		</div>
		<button type="submit" class="btn" style="width: 100%;">Add</button>
	    </form>
	</div>
	<%
		con.rollback();
	    }
	    con.setAutoCommit(true);
	} else {
	    err = 2;
    %>
    <div class="card container-input">
    <form action="add-member.jsp" method="post">
	<div class="form-row">
	    <label>Username</label>
	    <input id="username" name="username" type="text" value="<%= username %>" />
	</div>
	<div class="form-row">
	    <label>Password<% if (password1.equals("")) out.print(" (re-enter)"); %></label>
	    <input id="password1" name="password1" type="password" value="<%= password1 %>" />
	</div>
	<div class="form-row">
	    <label>Password Again (re-enter)</label>
	    <input id="password2" name="password2" type="password" />
	</div>
	<div class="form-row">
	    <label>First name</label>
	    <input id="fname" name="fname" type="text" value="<%= fname %>" />
	    <label>Last name</label>
	    <input id="lname" name="lname" type="text" value="<%= lname %>" />
	</div>
	<div class="form-row">
	    <label>Health notes:</label>
	    <textarea id="health_notes" name="health_notes" rows="3"><%= health_notes %></textarea>
	</div>
	<div class="form-row">
	    <label>Goals:</label>
	    <textarea id="goals" name="goals" rows="3"><%= goals %></textarea>
	</div>
	<div class="form-row">
	    <input id="active_flag" name="active_flag" type="checkbox" value="active_flag" <% if (active_flag != null) out.print("checked"); %> />
	    <label class="check">Active</label>
	</div>
	<button type="submit" class="btn" style="width: 100%;">Add</button>
    </form>
    </div>
    <% }
    } else { %>
    <div class="card container-input">
    <form action="add-member.jsp" method="post">
	<div class="form-row">
	    <label>Username</label>
	    <input id="username" name="username" type="text" />
	</div>
	<div class="form-row">
	    <label>Password</label>
	    <input id="password1" name="password1" type="password" />
	</div>
	<div class="form-row">
	    <label>Password Again</label>
	    <input id="password2" name="password2" type="password" />
	</div>
	<div class="form-row">
	    <label>First name</label>
	    <input id="fname" name="fname" type="text" />
	    <label>Last name</label>
	    <input id="lname" name="lname" type="text" />
	</div>
	<div class="form-row">
	    <label>Health notes:</label>
	    <textarea id="health_notes" name="health_notes" rows="3"></textarea>
	</div>
	<div class="form-row">
	    <label>Goals:</label>
	    <textarea id="goals" name="goals" rows="3"></textarea>
	</div>
	<div class="form-row">
	    <input id="active_flag" name="active_flag" type="checkbox" value="active_flag" checked />
	    <label class="check">Active</label>
	</div>
	<button type="submit" class="btn" style="width: 100%;">Add</button>
    </form>
    </div>
    <% } %>
</body>
</html>