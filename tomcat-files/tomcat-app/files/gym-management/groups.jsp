<%@ include file="/WEB-INF/includes/auth-check.jspf" %>
<%
    if (auth_user_id < 0) {
	response.sendRedirect("/tomcat-app/gym-management/");
	return;
    }

    boolean is_member = (auth_user_type == 1);
    boolean is_admin = (auth_user_type == 0) && (auth_admin_flag == 1);

    /* Managing groups: members can join/leave the groups they train with */
    String action_message = null;
    if (request.getMethod().equals("POST") && is_member && (con != null)) {
	String action = request.getParameter("action");
	String group_id_param = request.getParameter("group_id");
	if ((action != null) && (group_id_param != null)) {
	    if (auth_member_active != 1) {
		action_message = "Your membership is inactive, so you can't join or leave groups.";
	    } else {
		try {
		    int group_id = Integer.parseInt(group_id_param);
		    if ("join".equals(action)) {
			PreparedStatement join_stmt = con.prepareStatement(
"INSERT IGNORE INTO group_membership (group_id, member_id) VALUES (?, ?)");
			join_stmt.setInt(1, group_id);
			join_stmt.setInt(2, auth_user_id);
			join_stmt.executeUpdate();
			join_stmt.close();
			action_message = "You've joined the group.";
		    } else if ("leave".equals(action)) {
			PreparedStatement leave_stmt = con.prepareStatement(
"DELETE FROM group_membership WHERE group_id = ? AND member_id = ?");
			leave_stmt.setInt(1, group_id);
			leave_stmt.setInt(2, auth_user_id);
			leave_stmt.executeUpdate();
			leave_stmt.close();
			action_message = "You've left the group.";
		    }
		} catch(Exception e) {
		    action_message = "Unable to update your group membership.";
		}
	    }
	}
    }

    /* Active groups available in the gym, per the "Managing groups" functional requirement */
    java.util.List<java.util.Map<String,Object>> groups = new java.util.ArrayList<>();
    if (con != null) {
	String sql =
"SELECT g.group_id, g.duration, "
+ "g.Monday_time, g.Tuesday_time, g.Wednesday_time, g.Thursday_time, "
+ "g.Friday_time, g.Saturday_time, g.Sunday_time, "
+ "(SELECT sp.sport_name FROM sport_groups sg JOIN sports sp ON sp.sport_id = sg.sport_id "
+ " WHERE sg.group_id = g.group_id LIMIT 1) AS sport_name, "
+ "(SELECT GROUP_CONCAT(loc.location_name SEPARATOR ', ') FROM location_groups lg "
+ " JOIN locations loc ON loc.location_id = lg.location_id WHERE lg.group_id = g.group_id) AS location_names, "
+ "(SELECT COUNT(*) FROM group_membership gm WHERE gm.group_id = g.group_id) AS enrolled, "
+ "(SELECT EXISTS(SELECT 1 FROM group_membership gm2 WHERE gm2.group_id = g.group_id AND gm2.member_id = ?)) AS is_member "
+ "FROM `groups` g WHERE g.active_flag = 1 ORDER BY sport_name, g.group_id";
	try {
	    PreparedStatement stmt = con.prepareStatement(sql);
	    stmt.setInt(1, is_member ? auth_user_id : -1);
	    ResultSet rs = stmt.executeQuery();
	    while (rs.next()) {
		java.util.Map<String,Object> row = new java.util.LinkedHashMap<>();
		row.put("group_id", rs.getInt("group_id"));
		row.put("duration", rs.getInt("duration"));
		row.put("sport_name", rs.getString("sport_name"));
		row.put("location_names", rs.getString("location_names"));
		row.put("enrolled", rs.getInt("enrolled"));
		row.put("is_member", rs.getBoolean("is_member"));
		String[] days = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"};
		java.util.List<String> chips = new java.util.ArrayList<>();
		for (String day : days) {
		    java.sql.Time t = rs.getTime(day + "_time");
		    if (t != null) {
			chips.add(day.substring(0, 3) + " " + new java.text.SimpleDateFormat("h:mm a").format(t));
		    }
		}
		row.put("schedule_chips", chips);
		groups.add(row);
	    }
	    rs.close();
	    stmt.close();
	} catch(SQLException e) {
	}
    }
    String active_page = "groups";
%>
<html>
<head>
    <meta charset="UTF-8" />
    <title>Groups &mdash; Gym Management System</title>
    <link rel="stylesheet" href="style.css" />
</head>
<body>
    <%@ include file="/WEB-INF/includes/navbar.jspf" %>
    <main class="container">
	<div class="card">
	    <div class="card-header">
		<div>
		    <h1>Groups</h1>
		    <p class="subtitle">
			<% if (is_member) { %>
			Browse active groups and join or leave the ones you train with.
			<% } else { %>
			Active groups currently running at the gym.
			<% } %>
		    </p>
		</div>
	    </div>

	    <% if (action_message != null) { %>
	    <div class="message message-success"><%= action_message %></div>
	    <% } %>

	    <% if (groups.isEmpty()) { %>
	    <p class="empty-state">No active groups right now.</p>
	    <% } else { %>
	    <div class="group-grid">
		<% for (java.util.Map<String,Object> row : groups) {
		    boolean member_here = Boolean.TRUE.equals(row.get("is_member"));
		    @SuppressWarnings("unchecked")
		    java.util.List<String> chips = (java.util.List<String>) row.get("schedule_chips");
		%>
		<div class="group-card">
		    <div class="group-card-title">
			<%= row.get("sport_name") != null ? row.get("sport_name") : "Group #" + row.get("group_id") %>
		    </div>
		    <div class="group-card-meta">
			<%= row.get("location_names") != null ? row.get("location_names") : "Location TBD" %>
			&middot; <%= row.get("duration") %> min
		    </div>
		    <div class="chip-row">
			<% if (chips.isEmpty()) { %>
			<span class="chip">Schedule TBD</span>
			<% } else {
			    for (String chip : chips) {
			%>
			<span class="chip"><%= chip %></span>
			<% } } %>
		    </div>
		    <div class="group-card-footer">
			<span class="badge badge-muted"><%= row.get("enrolled") %> enrolled</span>
			<% if (is_member) { %>
			<form action="groups.jsp" method="post" class="inline-form">
			    <input type="hidden" name="group_id" value="<%= row.get("group_id") %>" />
			    <% if (member_here) { %>
			    <input type="hidden" name="action" value="leave" />
			    <button type="submit" class="btn btn-danger btn-sm">Leave</button>
			    <% } else { %>
			    <input type="hidden" name="action" value="join" />
			    <button type="submit" class="btn btn-sm">Join</button>
			    <% } %>
			</form>
			<% } %>
		    </div>
		</div>
		<% } %>
	    </div>
	    <% } %>
	</div>
    </main>
    <%
    if (con != null) con.close();
    %>
</body>
</html>
