<%@ page import="java.sql.*, javax.naming.*, javax.sql.DataSource" %>
<%@ include file="/WEB-INF/includes/auth-check.jspf" %>
<%
    if ((auth_admin_flag != 1) || (con == null)) {
        response.sendRedirect("/tomcat-app/gym-management/");
	if (con != null) try { con.close(); } catch (SQLException ignore) {}
        return;
    }

    String active_page = "add-employee";
%>
<!DOCTYPE html>
<html>
<head>
    <title>Add Employee - Gym Management System</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <%@ include file="/WEB-INF/includes/navbar.jspf" %>
    <% if (request.getMethod().equals("POST")) {
	int err = 1;
	String username = request.getParameter("username");
	String password1 = request.getParameter("password1");
	String password2 = request.getParameter("password2");
	String fname = request.getParameter("fname");
	String lname = request.getParameter("lname");
	String coach_flag = request.getParameter("coach_flag");
	String admin_flag = request.getParameter("admin_flag");
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

		    String insert_user_sql =
		    "INSERT INTO users (user_name, user_password, user_id, "
		    + "user_type, "
		    + "first_name, last_name, start_date, end_date, "
		    + "cookie_value, cookie_expiration_time, active_flag) "
		    + "VALUES(?, ?, ?, 0, ?, ?, ?, null, null, null, ?)";

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

		    String insert_empl_sql =
		    "INSERT INTO employees (user_id, "
		    + "admin_flag, coach_flag) "
		    + "VALUES(?, ?, ?)";
		    PreparedStatement insert_empl_stmt =
		    con.prepareStatement(insert_empl_sql);
		    insert_empl_stmt.setInt(1, new_user_id);
		    insert_empl_stmt.setInt(2, (admin_flag != null) ? 1 : 0);
		    insert_empl_stmt.setInt(3, (coach_flag != null) ? 1 : 0);
		    insert_empl_stmt.executeUpdate();
		    insert_empl_stmt.close();
    %>
    <div class="card container-input">
	<form action="add-employee.jsp" method="get">
	    <div class="form-row">
		<label>Employee added successfully</label>
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
		<label class="result"><% if (coach_flag != null) out.print("Coach "); %></label>
		<label class="result"><% if (admin_flag != null) out.print("Administrator "); %></label>
		<label class="result"><% if (active_flag != null) out.print("(Active)"); else out.print("(Inactive)"); %></label>
	    </div>
	    <button type="submit" class="btn" style="width: 100%;">Add another employee</button>
	</form>
    </div>
    <%
		    con.commit();
		    err = 0;
		} else {
		    con.rollback();
		}
		getid_res.close();
		getid_stmt.close();
	    } catch (SQLException e) {
    %>
	<div class="card container-input">
	    <form action="add-employee.jsp" method="post">
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
		    <input id="coach_flag" name="coach_flag" type="checkbox" value="coach_flag" <% if (coach_flag != null) out.print("checked"); %> />
		    <label class="check">Coach</label>
		    <input id="admin_flag" name="admin_flag" type="checkbox" value="admin_flag" <% if (admin_flag != null) out.print("checked"); %> />
		    <label class="check">Administrator</label>
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
    <form action="add-employee.jsp" method="post">
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
	    <input id="coach_flag" name="coach_flag" type="checkbox" value="coach_flag" <% if (coach_flag != null) out.print("checked"); %> />
	    <label class="check">Coach</label>
	    <input id="admin_flag" name="admin_flag" type="checkbox" value="admin_flag" <% if (admin_flag != null) out.print("checked"); %> />
	    <label class="check">Administrator</label>
	    <input id="active_flag" name="active_flag" type="checkbox" value="active_flag" <% if (active_flag != null) out.print("checked"); %> />
	    <label class="check">Active</label>
	</div>
	<button type="submit" class="btn" style="width: 100%;">Add</button>
    </form>
    </div>
    <% }
    } else { %>
    <div class="card container-input">
    <form action="add-employee.jsp" method="post">
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
	    <input id="coach_flag" name="coach_flag" type="checkbox" value="coach_flag" />
	    <label class="check">Coach</label>
	    <input id="admin_flag" name="admin_flag" type="checkbox" value="admin_flag" />
	    <label class="check">Administrator</label>
	    <input id="active_flag" name="active_flag" type="checkbox" value="active_flag" checked />
	    <label class="check">Active</label>
	</div>
	<button type="submit" class="btn" style="width: 100%;">Add</button>
    </form>
    </div>
    <% }
    try { con.close(); } catch (SQLException ignore) {}
    %>
</body>
</html>
