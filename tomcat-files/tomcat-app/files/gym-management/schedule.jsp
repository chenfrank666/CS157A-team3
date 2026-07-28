<%@ page import="java.text.SimpleDateFormat"%>
<%@ include file="/WEB-INF/includes/auth-check.jspf" %>
<%
    if (auth_user_id < 0) {
	response.sendRedirect("/tomcat-app/gym-management/");
	return;
    }

    boolean is_coach = (auth_user_type == 0) && (auth_coach_flag == 1);
    boolean is_admin = (auth_user_type == 0) && (auth_admin_flag == 1);
    boolean is_member = (auth_user_type == 1);
    boolean can_view_schedule = is_member || is_coach || is_admin;
    boolean can_toggle_view = is_member || is_coach;

    String view = request.getParameter("view");
    boolean show_mine = can_toggle_view && !"all".equals(view);
    String query_string = show_mine ? "" : "?view=all";
    String mine_href = "schedule.jsp";
    String all_href = "schedule.jsp?view=all";

    /* Administrators can cancel a class directly (functional requirement:
       "Administrators can select classes for cancellation") */
    String cancel_message = null;
    if (request.getMethod().equals("POST") && is_admin && (con != null)) {
	String cancel_group = request.getParameter("cancel_group_id");
	String cancel_date = request.getParameter("cancel_date");
	String cancel_reason = request.getParameter("cancel_reason");
	if ((cancel_group != null) && (cancel_date != null)) {
	    try {
		PreparedStatement cancel_stmt = con.prepareStatement(
"INSERT INTO cancellations (group_id, `date`, reason) VALUES (?, ?, ?) "
+ "ON DUPLICATE KEY UPDATE reason = VALUES(reason)");
		cancel_stmt.setInt(1, Integer.parseInt(cancel_group));
		cancel_stmt.setDate(2, java.sql.Date.valueOf(cancel_date));
		cancel_stmt.setString(3, ((cancel_reason == null) || cancel_reason.trim().isEmpty())
		    ? "Cancelled by administrator" : cancel_reason.trim());
		cancel_stmt.executeUpdate();
		cancel_stmt.close();
		cancel_message = "The class on " + cancel_date + " has been cancelled.";
	    } catch(Exception e) {
		cancel_message = "Unable to cancel that class.";
	    }
	}
    }

    /* Next two weeks of classes, per the "View schedule" functional requirement */
    java.util.List<java.util.Map<String,Object>> classes = new java.util.ArrayList<>();
    if (can_view_schedule && (con != null)) {
	StringBuilder sql = new StringBuilder();
	sql.append("SELECT cs.group_id, cs.`date` AS class_date, cs.`time` AS class_time, g.duration, ");
	sql.append("(SELECT sp.sport_name FROM sport_groups sg JOIN sports sp ON sp.sport_id = sg.sport_id ");
	sql.append(" WHERE sg.group_id = g.group_id LIMIT 1) AS sport_name, ");
	sql.append("(SELECT GROUP_CONCAT(loc.location_name SEPARATOR ', ') FROM location_groups lg ");
	sql.append(" JOIN locations loc ON loc.location_id = lg.location_id WHERE lg.group_id = g.group_id) AS location_names, ");
	sql.append("(SELECT CONCAT(u.first_name, ' ', u.last_name) FROM class_coach cc ");
	sql.append(" JOIN users u ON u.user_id = cc.user_id ");
	sql.append(" WHERE cc.group_id = cs.group_id AND cc.`date` = cs.`date` LIMIT 1) AS coach_name, ");
	sql.append("(SELECT COUNT(*) FROM group_membership gm WHERE gm.group_id = cs.group_id) AS enrolled, ");
	sql.append("(SELECT reason FROM cancellations c WHERE c.group_id = cs.group_id AND c.`date` = cs.`date`) AS cancel_reason ");
	sql.append("FROM class_schedule cs JOIN `groups` g ON g.group_id = cs.group_id ");
	sql.append("WHERE cs.`date` BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 14 DAY) ");
	if (show_mine && is_member) {
	    sql.append("AND EXISTS (SELECT 1 FROM group_membership gm2 WHERE gm2.group_id = cs.group_id AND gm2.member_id = ?) ");
	} else if (show_mine && is_coach) {
	    sql.append("AND EXISTS (SELECT 1 FROM class_coach cc2 WHERE cc2.group_id = cs.group_id ");
	    sql.append(" AND cc2.`date` = cs.`date` AND cc2.user_id = ?) ");
	}
	sql.append("ORDER BY cs.`date`, cs.`time`");
	try {
	    PreparedStatement stmt = con.prepareStatement(sql.toString());
	    if (show_mine && (is_member || is_coach)) {
		stmt.setInt(1, auth_user_id);
	    }
	    ResultSet rs = stmt.executeQuery();
	    while (rs.next()) {
		java.util.Map<String,Object> row = new java.util.HashMap<>();
		row.put("group_id", rs.getInt("group_id"));
		row.put("date", rs.getDate("class_date"));
		row.put("time", rs.getTime("class_time"));
		row.put("duration", rs.getInt("duration"));
		row.put("sport_name", rs.getString("sport_name"));
		row.put("location_names", rs.getString("location_names"));
		row.put("coach_name", rs.getString("coach_name"));
		row.put("enrolled", rs.getInt("enrolled"));
		row.put("cancel_reason", rs.getString("cancel_reason"));
		classes.add(row);
	    }
	    rs.close();
	    stmt.close();
	} catch(SQLException e) {
	}
    }

    SimpleDateFormat date_fmt = new SimpleDateFormat("EEE, MMM d");
    SimpleDateFormat time_fmt = new SimpleDateFormat("h:mm a");
    String active_page = "schedule";
%>
<html>
<head>
    <meta charset="UTF-8" />
    <title>Schedule &mdash; Gym Management System</title>
    <link rel="stylesheet" href="style.css" />
</head>
<body>
    <%@ include file="/WEB-INF/includes/navbar.jspf" %>
    <main class="container">
	<% if (!can_view_schedule) { %>
	<div class="card">
	    <h1>Schedule</h1>
	    <p class="subtitle">Your account doesn't have a class schedule to view. Contact an administrator if you believe this is a mistake.</p>
	</div>
	<% } else { %>
	<div class="card">
	    <div class="card-header">
		<div>
		    <h1>Class Schedule</h1>
		    <p class="subtitle">Classes over the next two weeks.</p>
		</div>
		<% if (can_toggle_view) { %>
		<div class="tabs">
		    <a class="tab <%= show_mine ? "active" : "" %>" href="<%= mine_href %>">My classes</a>
		    <a class="tab <%= !show_mine ? "active" : "" %>" href="<%= all_href %>">All classes</a>
		</div>
		<% } %>
	    </div>

	    <% if (cancel_message != null) { %>
	    <div class="message message-success"><%= cancel_message %></div>
	    <% } %>

	    <% if (classes.isEmpty()) { %>
	    <p class="empty-state">No classes scheduled in this window.</p>
	    <% } else { %>
	    <table>
		<thead>
		    <tr>
			<th>Date</th>
			<th>Time</th>
			<th>Sport</th>
			<th>Location</th>
			<th>Coach</th>
			<th>Enrolled</th>
			<th></th>
		    </tr>
		</thead>
		<tbody>
		    <% for (java.util.Map<String,Object> row : classes) {
			boolean cancelled = row.get("cancel_reason") != null;
		    %>
		    <tr class="<%= cancelled ? "row-cancelled" : "" %>">
			<td><%= date_fmt.format((java.util.Date) row.get("date")) %></td>
			<td><%= time_fmt.format((java.util.Date) row.get("time")) %></td>
			<td><%= row.get("sport_name") != null ? row.get("sport_name") : "&mdash;" %></td>
			<td><%= row.get("location_names") != null ? row.get("location_names") : "&mdash;" %></td>
			<td><%= row.get("coach_name") != null ? row.get("coach_name") : "&mdash;" %></td>
			<td><%= row.get("enrolled") %></td>
			<td>
			    <% if (cancelled) { %>
			    <span class="badge badge-cancelled">Cancelled</span>
			    <% } else if (is_admin) { %>
			    <form action="schedule.jsp<%= query_string %>" method="post" class="inline-form">
				<input type="hidden" name="cancel_group_id" value="<%= row.get("group_id") %>" />
				<input type="hidden" name="cancel_date" value="<%= row.get("date") %>" />
				<button type="submit" class="btn btn-danger btn-sm"
					onclick="return confirm('Cancel this class?');">Cancel</button>
			    </form>
			    <% } %>
			</td>
		    </tr>
		    <% if (cancelled) { %>
		    <tr class="row-cancelled">
			<td colspan="7" style="padding-top:0; font-size:0.82rem;">Reason: <%= row.get("cancel_reason") %></td>
		    </tr>
		    <% } %>
		    <% } %>
		</tbody>
	    </table>
	    <% } %>
	</div>
	<% } %>
    </main>
    <%
    if (con != null) con.close();
    %>
</body>
</html>
