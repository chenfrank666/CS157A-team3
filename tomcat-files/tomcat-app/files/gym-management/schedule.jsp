<%@ page import="java.text.SimpleDateFormat"%>
<%@ include file="/WEB-INF/includes/auth-check.jspf" %>
<%
    if ((auth_user_id < 0) || (con == null)) {
	response.sendRedirect("/tomcat-app/gym-management/");
	if (con != null) try { con.close(); } catch (SQLException ignore) {}
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
    if (request.getMethod().equals("POST") && is_admin) {
	String cancel_group = request.getParameter("cancel_group_id");
	String cancel_date = request.getParameter("cancel_date");
	String cancel_reason = request.getParameter("cancel_reason");
	if ((cancel_group != null) && (cancel_date != null)) {
	    try {
		int cancel_group_id = Integer.parseInt(cancel_group);
		java.sql.Date cancel_sql_date = java.sql.Date.valueOf(cancel_date);
		String reason_text = ((cancel_reason == null) || cancel_reason.trim().isEmpty())
		    ? "Cancelled by administrator" : cancel_reason.trim();

		PreparedStatement exists_stmt = con.prepareStatement(
"SELECT reason FROM cancellations WHERE group_id = ? AND `date` = ?");
		exists_stmt.setInt(1, cancel_group_id);
		exists_stmt.setDate(2, cancel_sql_date);
		ResultSet exists_rs = exists_stmt.executeQuery();
		boolean already_cancelled = exists_rs.next();
		exists_rs.close();
		exists_stmt.close();

		if (already_cancelled) {
		    PreparedStatement update_stmt = con.prepareStatement(
"UPDATE cancellations SET reason = ? WHERE group_id = ? AND `date` = ?");
		    update_stmt.setString(1, reason_text);
		    update_stmt.setInt(2, cancel_group_id);
		    update_stmt.setDate(3, cancel_sql_date);
		    update_stmt.executeUpdate();
		    update_stmt.close();
		} else {
		    PreparedStatement insert_stmt = con.prepareStatement(
"INSERT INTO cancellations (group_id, `date`, reason) VALUES (?, ?, ?)");
		    insert_stmt.setInt(1, cancel_group_id);
		    insert_stmt.setDate(2, cancel_sql_date);
		    insert_stmt.setString(3, reason_text);
		    insert_stmt.executeUpdate();
		    insert_stmt.close();
		}
		cancel_message = "The class on " + cancel_date + " has been cancelled.";
	    } catch(Exception e) {
		cancel_message = "Unable to cancel that class.";
	    }
	}
    }

    /* Next two weeks of classes, per the "View schedule" functional requirement */
    java.util.List<java.util.Map<String,Object>> classes = new java.util.ArrayList<>();
    if (can_view_schedule) {
	try {
	    java.sql.Date window_start = new java.sql.Date(System.currentTimeMillis());
	    java.sql.Date window_end = new java.sql.Date(
		System.currentTimeMillis() + 14L * 24 * 60 * 60 * 1000);

	    String classes_sql =
"SELECT cs.group_id, cs.`date` AS class_date, cs.`time` AS class_time, g.duration, sp.sport_name "
+ "FROM class_schedule cs "
+ "JOIN `groups` g ON g.group_id = cs.group_id "
+ "LEFT JOIN sport_groups sg ON sg.group_id = g.group_id "
+ "LEFT JOIN sports sp ON sp.sport_id = sg.sport_id "
+ "WHERE cs.`date` >= ? AND cs.`date` <= ? "
+ "ORDER BY cs.`date`, cs.`time`";
	    PreparedStatement classes_stmt = con.prepareStatement(classes_sql);
	    classes_stmt.setDate(1, window_start);
	    classes_stmt.setDate(2, window_end);
	    ResultSet classes_rs = classes_stmt.executeQuery();
	    while (classes_rs.next()) {
		java.util.Map<String,Object> row = new java.util.HashMap<>();
		row.put("group_id", classes_rs.getInt("group_id"));
		row.put("date", classes_rs.getDate("class_date"));
		row.put("time", classes_rs.getTime("class_time"));
		row.put("duration", classes_rs.getInt("duration"));
		row.put("sport_name", classes_rs.getString("sport_name"));
		row.put("location_names", null);
		row.put("coach_name", null);
		row.put("enrolled", 0);
		row.put("cancel_reason", null);
		classes.add(row);
	    }
	    classes_rs.close();
	    classes_stmt.close();

	    
	    java.util.Map<Integer,java.util.List<String>> locations_by_group = new java.util.HashMap<>();
	    String locations_sql =
"SELECT lg.group_id, loc.location_name "
+ "FROM location_groups lg "
+ "JOIN locations loc ON loc.location_id = lg.location_id "
+ "ORDER BY lg.group_id, loc.location_name";
	    Statement locations_stmt = con.createStatement();
	    ResultSet locations_rs = locations_stmt.executeQuery(locations_sql);
	    while (locations_rs.next()) {
		int loc_group_id = locations_rs.getInt("group_id");
		locations_by_group.computeIfAbsent(loc_group_id, k -> new java.util.ArrayList<>())
		    .add(locations_rs.getString("location_name"));
	    }
	    locations_rs.close();
	    locations_stmt.close();

	    java.util.Map<String,String> coach_by_key = new java.util.HashMap<>();
	    String coach_sql =
"SELECT cc.group_id, cc.`date`, u.first_name, u.last_name "
+ "FROM class_coach cc "
+ "JOIN users u ON u.user_id = cc.user_id "
+ "WHERE cc.`date` >= ? AND cc.`date` <= ?";
	    PreparedStatement coach_stmt = con.prepareStatement(coach_sql);
	    coach_stmt.setDate(1, window_start);
	    coach_stmt.setDate(2, window_end);
	    ResultSet coach_rs = coach_stmt.executeQuery();
	    while (coach_rs.next()) {
		String coach_key = coach_rs.getInt("group_id") + "|" + coach_rs.getDate("date");
		if (!coach_by_key.containsKey(coach_key)) {
		    coach_by_key.put(coach_key, coach_rs.getString("first_name") + " " + coach_rs.getString("last_name"));
		}
	    }
	    coach_rs.close();
	    coach_stmt.close();

	    java.util.Map<Integer,Integer> enrolled_by_group = new java.util.HashMap<>();
	    String counts_sql = "SELECT group_id, COUNT(*) AS enrolled FROM group_membership GROUP BY group_id";
	    Statement counts_stmt = con.createStatement();
	    ResultSet counts_rs = counts_stmt.executeQuery(counts_sql);
	    while (counts_rs.next()) {
		enrolled_by_group.put(counts_rs.getInt("group_id"), counts_rs.getInt("enrolled"));
	    }
	    counts_rs.close();
	    counts_stmt.close();

	    java.util.Map<String,String> cancel_by_key = new java.util.HashMap<>();
	    String cancel_lookup_sql =
"SELECT group_id, `date`, reason FROM cancellations WHERE `date` >= ? AND `date` <= ?";
	    PreparedStatement cancel_lookup_stmt = con.prepareStatement(cancel_lookup_sql);
	    cancel_lookup_stmt.setDate(1, window_start);
	    cancel_lookup_stmt.setDate(2, window_end);
	    ResultSet cancel_lookup_rs = cancel_lookup_stmt.executeQuery();
	    while (cancel_lookup_rs.next()) {
		String cancel_key = cancel_lookup_rs.getInt("group_id") + "|" + cancel_lookup_rs.getDate("date");
		cancel_by_key.put(cancel_key, cancel_lookup_rs.getString("reason"));
	    }
	    cancel_lookup_rs.close();
	    cancel_lookup_stmt.close();

	    java.util.Set<Integer> my_group_ids = new java.util.HashSet<>();
	    if (show_mine && is_member) {
		PreparedStatement my_groups_stmt = con.prepareStatement(
"SELECT group_id FROM group_membership WHERE member_id = ?");
		my_groups_stmt.setInt(1, auth_user_id);
		ResultSet my_groups_rs = my_groups_stmt.executeQuery();
		while (my_groups_rs.next()) {
		    my_group_ids.add(my_groups_rs.getInt("group_id"));
		}
		my_groups_rs.close();
		my_groups_stmt.close();
	    }

	    /* This coach's own class_coach assignments in the window, same idea. */
	    java.util.Set<String> my_coach_keys = new java.util.HashSet<>();
	    if (show_mine && is_coach) {
		PreparedStatement my_coach_stmt = con.prepareStatement(
"SELECT group_id, `date` FROM class_coach WHERE user_id = ? AND `date` >= ? AND `date` <= ?");
		my_coach_stmt.setInt(1, auth_user_id);
		my_coach_stmt.setDate(2, window_start);
		my_coach_stmt.setDate(3, window_end);
		ResultSet my_coach_rs = my_coach_stmt.executeQuery();
		while (my_coach_rs.next()) {
		    my_coach_keys.add(my_coach_rs.getInt("group_id") + "|" + my_coach_rs.getDate("date"));
		}
		my_coach_rs.close();
		my_coach_stmt.close();
	    }

	    java.util.List<java.util.Map<String,Object>> filtered_classes = new java.util.ArrayList<>();
	    for (java.util.Map<String,Object> row : classes) {
		int row_group_id = (Integer) row.get("group_id");
		java.sql.Date row_date = (java.sql.Date) row.get("date");
		String row_key = row_group_id + "|" + row_date;

		java.util.List<String> row_locations = locations_by_group.get(row_group_id);
		if (row_locations != null) {
		    StringBuilder joined = new StringBuilder();
		    for (int i = 0; i < row_locations.size(); i++) {
			if (i > 0) joined.append(", ");
			joined.append(row_locations.get(i));
		    }
		    row.put("location_names", joined.toString());
		}
		row.put("coach_name", coach_by_key.get(row_key));
		row.put("enrolled", enrolled_by_group.getOrDefault(row_group_id, 0));
		row.put("cancel_reason", cancel_by_key.get(row_key));

		if (show_mine && is_member && !my_group_ids.contains(row_group_id)) continue;
		if (show_mine && is_coach && !my_coach_keys.contains(row_key)) continue;
		filtered_classes.add(row);
	    }
	    classes = filtered_classes;
	} catch(SQLException e) {
	}
    }

    SimpleDateFormat date_fmt = new SimpleDateFormat("EEE, MMM d");
    SimpleDateFormat time_fmt = new SimpleDateFormat("h:mm a");
    String active_page = "schedule";
%>
<!DOCTYPE html>
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
		<div style="display: flex; gap: 12px; align-items: center; flex-wrap: wrap;">
		    <% if (is_coach) { %>
			<a href="request-change.jsp" class="btn btn-secondary btn-sm">
			    + Request Schedule Change
			</a>
		    <% } %>
		    
		    <% if (can_toggle_view) { %>
			<div class="tabs">
			    <a class="tab <%= show_mine ? "active" : "" %>" href="<%= mine_href %>">My classes</a>
			    <a class="tab <%= !show_mine ? "active" : "" %>" href="<%= all_href %>">All classes</a>
			</div>
		    <% } %>
		</div>
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
    try { con.close(); } catch (SQLException ignore) {}
    %>
</body>
</html>
