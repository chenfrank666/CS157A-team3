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
			PreparedStatement check_stmt = con.prepareStatement(
"SELECT member_id FROM group_membership WHERE group_id = ? AND member_id = ?");
			check_stmt.setInt(1, group_id);
			check_stmt.setInt(2, auth_user_id);
			ResultSet check_rs = check_stmt.executeQuery();
			boolean already_member = check_rs.next();
			check_rs.close();
			check_stmt.close();
			if (!already_member) {
			    PreparedStatement join_stmt = con.prepareStatement(
"INSERT INTO group_membership (group_id, member_id) VALUES (?, ?)");
			    join_stmt.setInt(1, group_id);
			    join_stmt.setInt(2, auth_user_id);
			    join_stmt.executeUpdate();
			    join_stmt.close();
			}
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
	try {
	    /* Base group info, with a plain JOIN (not a subquery) to pick up each
	       group's sport. */
	    String groups_sql =
"SELECT g.group_id, g.duration, "
+ "g.Monday_time, g.Tuesday_time, g.Wednesday_time, g.Thursday_time, "
+ "g.Friday_time, g.Saturday_time, g.Sunday_time, sp.sport_name "
+ "FROM `groups` g "
+ "LEFT JOIN sport_groups sg ON sg.group_id = g.group_id "
+ "LEFT JOIN sports sp ON sp.sport_id = sg.sport_id "
+ "WHERE g.active_flag = 1 "
+ "ORDER BY sp.sport_name, g.group_id";
	    Statement groups_stmt = con.createStatement();
	    ResultSet groups_rs = groups_stmt.executeQuery(groups_sql);
	    while (groups_rs.next()) {
		java.util.Map<String,Object> row = new java.util.LinkedHashMap<>();
		row.put("group_id", groups_rs.getInt("group_id"));
		row.put("duration", groups_rs.getInt("duration"));
		row.put("sport_name", groups_rs.getString("sport_name"));
		row.put("location_names", null);
		row.put("enrolled", 0);
		row.put("is_member", false);
		String[] days = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"};
		java.util.List<String> chips = new java.util.ArrayList<>();
		for (String day : days) {
		    java.sql.Time t = groups_rs.getTime(day + "_time");
		    if (t != null) {
			chips.add(day.substring(0, 3) + " " + new java.text.SimpleDateFormat("h:mm a").format(t));
		    }
		}
		row.put("schedule_chips", chips);
		groups.add(row);
	    }
	    groups_rs.close();
	    groups_stmt.close();

	    /* Locations per group: one simple SELECT, joined in Java instead of GROUP_CONCAT. */
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

	    /* Enrollment counts per group: plain GROUP BY, no correlated subquery. */
	    java.util.Map<Integer,Integer> enrolled_by_group = new java.util.HashMap<>();
	    String counts_sql =
"SELECT group_id, COUNT(*) AS enrolled FROM group_membership GROUP BY group_id";
	    Statement counts_stmt = con.createStatement();
	    ResultSet counts_rs = counts_stmt.executeQuery(counts_sql);
	    while (counts_rs.next()) {
		enrolled_by_group.put(counts_rs.getInt("group_id"), counts_rs.getInt("enrolled"));
	    }
	    counts_rs.close();
	    counts_stmt.close();

	    /* Groups the current member already belongs to, so "is_member" is a
	       plain lookup instead of an EXISTS(...) subquery. */
	    java.util.Set<Integer> my_group_ids = new java.util.HashSet<>();
	    if (is_member) {
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

	    for (java.util.Map<String,Object> row : groups) {
		int row_group_id = (Integer) row.get("group_id");
		java.util.List<String> row_locations = locations_by_group.get(row_group_id);
		if (row_locations != null) {
		    StringBuilder joined = new StringBuilder();
		    for (int i = 0; i < row_locations.size(); i++) {
			if (i > 0) joined.append(", ");
			joined.append(row_locations.get(i));
		    }
		    row.put("location_names", joined.toString());
		}
		row.put("enrolled", enrolled_by_group.getOrDefault(row_group_id, 0));
		row.put("is_member", my_group_ids.contains(row_group_id));
	    }
	} catch(SQLException e) {
	}
    }
    String active_page = "groups";
%>
<!DOCTYPE html>
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
