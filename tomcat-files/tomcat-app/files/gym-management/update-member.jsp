<%@ page import="java.sql.*, javax.naming.*, javax.sql.DataSource" %>
<%@ include file="/WEB-INF/includes/auth-check.jspf" %>
<%
    if (auth_admin_flag != 1) {
	response.sendRedirect("/tomcat-app/gym-management/");
	return;
    }

    String active_page = "update-member";
    int update_user_id = -1;
    String update_user_id_str = request.getParameter("user_id");
    try {
	if ((update_user_id_str == null) || update_user_id_str.equals("")) {
	    response.sendRedirect("users.jsp");
	    return;
	}
	update_user_id=Integer.parseInt(update_user_id_str);
    } catch (Exception e) {
	response.sendRedirect("users.jsp");
	return;
    }
%>
<!DOCTYPE html>
<html>
<head>
    <title>Update Member - Gym Management System</title>
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

	con.setAutoCommit(false);
	try {
	    if (password1.equals(password2) && !password1.equals("")) {
		String update_user_password_sql =
		"UPDATE users SET user_password = ? "
		+ "WHERE user_id = ? AND user_type = 1";
		PreparedStatement update_user_password_stmt =
		con.prepareStatement(update_user_password_sql);
		update_user_password_stmt.setString(1, password1);
		update_user_password_stmt.setInt(2, update_user_id);
		update_user_password_stmt.executeUpdate();
		update_user_password_stmt.close();
	    }
	    String update_user_sql =
	    "UPDATE users SET user_name = ?, "
	    + "first_name = ?, last_name = ?, active_flag = ? "
	    + "WHERE user_id = ? AND user_type = 1";
	    PreparedStatement update_user_stmt =
	    con.prepareStatement(update_user_sql);
	    update_user_stmt.setString(1, username);
	    update_user_stmt.setString(2, fname);
	    update_user_stmt.setString(3, lname);
	    update_user_stmt.setInt(4, (active_flag != null) ? 1 : 0);
	    update_user_stmt.setInt(5, update_user_id);
	    update_user_stmt.executeUpdate();
	    update_user_stmt.close();

	    String update_memb_sql =
	    "UPDATE members SET goals = ?, health_notes = ? "
	    + "WHERE user_id = ?";
	    PreparedStatement update_memb_stmt =
	    con.prepareStatement(update_memb_sql);
	    update_memb_stmt.setString(1, goals);
	    update_memb_stmt.setString(2, health_notes);
	    update_memb_stmt.setInt(3, update_user_id);
	    update_memb_stmt.executeUpdate();
	    update_memb_stmt.close();
    %>
    <div class="card container-input">
	<form>
	    <div class="form-row">
		<label>Member updated successfully</label>
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
		<label class="result"><% if (active_flag != null) out.print("(Active)"); else out.print("(Inactive)"); %></label>
	    </div>
	</form>
	<form action="users.jsp" method="get">
	    <button type="submit" class="btn" style="width: 100%;">Back to users list</button>
	</form>
    </div>
    <%
	    con.commit();
	    err = 0;
	} catch (SQLException e) {
    %>
	<div class="card container-input">
	    <form action="update-member.jsp" method="post">
		<input id="user_id" name="user_id" type="hidden" value="<%= update_user_id_str %>" />
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
		<button type="submit" class="btn" style="width: 100%;">Update</button>
	    </form>
	</div>
	<%
	    con.rollback();
	}
	con.setAutoCommit(true);
    } else {
	String memQuery = "SELECT u.user_id, u.first_name, u.last_name, "
	+ "u.user_name, u.active_flag, e.goals, e.health_notes "
	+ "FROM users u JOIN members e ON u.user_id = e.user_id "
	+ "WHERE u.user_id = ? AND u.user_type = 1";
	PreparedStatement memStmt = con.prepareStatement(memQuery);
	memStmt.setInt(1, update_user_id);
        ResultSet memRs = memStmt.executeQuery();

        if(memRs.next()) {
    %>
    <div class="card container-input">
	<form action="update-member.jsp" method="post">
	    <input id="user_id" name="user_id" type="hidden" value="<%= update_user_id_str %>" />
	    <div class="form-row">
	    <label>Username</label>
	    <input id="username" name="username" type="text" value="<%= memRs.getString("u.user_name") %>" />
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
	    <input id="fname" name="fname" type="text" value="<%= memRs.getString("u.first_name") %>" />
	    <label>Last name</label>
	    <input id="lname" name="lname" type="text" value="<%= memRs.getString("u.last_name") %>" />
	</div>
	<div class="form-row">
	    <label>Health notes:</label>
	    <textarea id="health_notes" name="health_notes" rows="3"><%= memRs.getString("e.health_notes") %></textarea>
	</div>
	<div class="form-row">
	    <label>Goals:</label>
	    <textarea id="goals" name="goals" rows="3"><%= memRs.getString("e.goals") %></textarea>
	</div>
	<div class="form-row">
	    <input id="active_flag" name="active_flag" type="checkbox" value="active_flag" <% if (memRs.getInt("u.active_flag") == 1) out.print("checked"); %> />
	    <label class="check">Active</label>
	</div>
	<button type="submit" class="btn" style="width: 100%;">Update</button>
	</form>
    </div>
    <%  } else { %>
	<div class="card container-input">
	    <div class="form-row">
		No such user
	    </div>
	</div> 
	<%
	}
	memRs.close();
	memStmt.close();
    }
con.close();
%>
</body>
</html>
