<%@ page import="java.sql.*, javax.naming.*, javax.sql.DataSource, java.text.SimpleDateFormat" %>
<%@ include file="/WEB-INF/includes/auth-check.jspf" %>
<%!
    private static String requestTypeLabel(int type) {
	switch (type) {
	    case 0: return "Cancel class";
	    case 1: return "Join as coach";
	    case 2: return "Leave as coach";
	    default: return "Unknown request";
	}
    }
%>
<%
    boolean is_coach = (auth_user_type == 0) && (auth_coach_flag == 1);
    boolean is_admin = (auth_user_type == 0) && (auth_admin_flag == 1);
    if (!is_coach && !is_admin || (con == null)) {
	response.sendRedirect("/tomcat-app/gym-management/");
	if (con != null) try { con.close(); } catch (SQLException ignore) {}
	return;
    }

    String message = null;
    String message_type = "success";

    /* Coach: submit a new request to cancel a class, become a coach for a
       group's session, or step down from one, per the "Coach schedule
       change" functional requirement. */
    if (request.getMethod().equals("POST") && "submit".equals(request.getParameter("form_action"))
	    && is_coach) {
	try {
	    int req_type = Integer.parseInt(request.getParameter("request_type"));
	    int group_id = Integer.parseInt(request.getParameter("group_id"));
	    java.sql.Date target_date = java.sql.Date.valueOf(request.getParameter("target_date"));
	    String reason = request.getParameter("reason");
	    if ((reason != null) && reason.trim().isEmpty()) reason = null;

	    if ((req_type < 0) || (req_type > 2)) {
		message = "Invalid request type.";
		message_type = "error";
	    } else {
		con.setAutoCommit(false);
		try {
		    PreparedStatement ins_req = con.prepareStatement(
			"INSERT INTO requests (request_type, request_text, request_date, target_date) "
			+ "VALUES (?, ?, CURDATE(), ?)");
		    ins_req.setInt(1, req_type);
		    ins_req.setString(2, reason);
		    ins_req.setDate(3, target_date);
		    ins_req.executeUpdate();
		    ins_req.close();

		    Statement id_stmt = con.createStatement();
		    ResultSet id_rs = id_stmt.executeQuery("SELECT LAST_INSERT_ID()");
		    id_rs.next();
		    int new_request_id = id_rs.getInt(1);
		    id_rs.close();
		    id_stmt.close();

		    PreparedStatement ins_emp = con.prepareStatement(
			"INSERT INTO request_employee (request_id, user_id) VALUES (?, ?)");
		    ins_emp.setInt(1, new_request_id);
		    ins_emp.setInt(2, auth_user_id);
		    ins_emp.executeUpdate();
		    ins_emp.close();

		    PreparedStatement ins_grp = con.prepareStatement(
			"INSERT INTO request_group (request_id, group_id) VALUES (?, ?)");
		    ins_grp.setInt(1, new_request_id);
		    ins_grp.setInt(2, group_id);
		    ins_grp.executeUpdate();
		    ins_grp.close();

		    con.commit();
		    message = "Your request has been submitted for admin approval.";
		} catch (Exception e) {
		    con.rollback();
		    message = "Unable to submit request. Make sure the group exists.";
		    message_type = "error";
		}
		con.setAutoCommit(true);
	    }
	} catch (Exception e) {
	    message = "Invalid request details.";
	    message_type = "error";
	}
    }

    /* Coach: withdraw one of their own still-pending requests. */
    if (request.getMethod().equals("POST") && "withdraw".equals(request.getParameter("form_action"))
	    && is_coach) {
	try {
	    int request_id = Integer.parseInt(request.getParameter("request_id"));
	    PreparedStatement owns_stmt = con.prepareStatement(
		"SELECT 1 FROM request_employee WHERE request_id = ? AND user_id = ?");
	    owns_stmt.setInt(1, request_id);
	    owns_stmt.setInt(2, auth_user_id);
	    ResultSet owns_rs = owns_stmt.executeQuery();
	    if (owns_rs.next()) {
		owns_rs.close();
		owns_stmt.close();
		PreparedStatement del_stmt = con.prepareStatement("DELETE FROM requests WHERE request_id = ?");
		del_stmt.setInt(1, request_id);
		del_stmt.executeUpdate();
		del_stmt.close();
		message = "Request withdrawn.";
	    } else {
		owns_rs.close();
		owns_stmt.close();
		message = "That request doesn't belong to you.";
		message_type = "error";
	    }
	} catch (Exception e) {
	    message = "Unable to withdraw request.";
	    message_type = "error";
	}
    }

    /* Administrator: approve or reject a pending request, per the
       "Approving request" functional requirement. Approving applies the
       underlying schedule change and archives (removes) the request. */
    if (request.getMethod().equals("POST")
	    && ("approve".equals(request.getParameter("form_action")) || "reject".equals(request.getParameter("form_action")))
	    && is_admin) {
	boolean approve = "approve".equals(request.getParameter("form_action"));
	try {
	    int request_id = Integer.parseInt(request.getParameter("request_id"));
	    PreparedStatement lookup = con.prepareStatement(
		"SELECT r.request_type, r.target_date, r.request_text, rg.group_id, re.user_id "
		+ "FROM requests r, request_group rg, request_employee re "
		+ "WHERE r.request_id = rg.request_id AND r.request_id = re.request_id AND r.request_id = ?");
	    lookup.setInt(1, request_id);
	    ResultSet lr = lookup.executeQuery();
	    if (lr.next()) {
		int req_type = lr.getInt("request_type");
		java.sql.Date target_date = lr.getDate("target_date");
		String reason = lr.getString("request_text");
		int group_id = lr.getInt("group_id");
		int coach_user_id = lr.getInt("user_id");
		lr.close();
		lookup.close();

		if (!approve) {
		    PreparedStatement del_stmt = con.prepareStatement("DELETE FROM requests WHERE request_id = ?");
		    del_stmt.setInt(1, request_id);
		    del_stmt.executeUpdate();
		    del_stmt.close();
		    message = "Request rejected.";
		} else {
		    con.setAutoCommit(false);
		    try {
			if (req_type == 0) {
			    PreparedStatement cancel_stmt = con.prepareStatement(
				"INSERT INTO cancellations (group_id, `date`, reason) VALUES (?, ?, ?) "
				+ "ON DUPLICATE KEY UPDATE reason = VALUES(reason)");
			    cancel_stmt.setInt(1, group_id);
			    cancel_stmt.setDate(2, target_date);
			    cancel_stmt.setString(3, (reason == null) ? "Cancelled per coach request" : reason);
			    cancel_stmt.executeUpdate();
			    cancel_stmt.close();
			} else if (req_type == 1) {
			    PreparedStatement sched_check = con.prepareStatement(
				"SELECT `time` FROM class_schedule WHERE group_id = ? AND `date` = ?");
			    sched_check.setInt(1, group_id);
			    sched_check.setDate(2, target_date);
			    ResultSet sched_rs = sched_check.executeQuery();
			    boolean has_schedule = sched_rs.next();
			    sched_rs.close();
			    sched_check.close();

			    if (!has_schedule) {
				throw new SQLException(
				    "No class is scheduled for that group on that date yet. "
				    + "Add it to the schedule first, then approve this request.");
			    }

			    PreparedStatement ins_coach = con.prepareStatement(
				"INSERT INTO class_coach (group_id, `date`, user_id) VALUES (?, ?, ?)");
			    ins_coach.setInt(1, group_id);
			    ins_coach.setDate(2, target_date);
			    ins_coach.setInt(3, coach_user_id);
			    ins_coach.executeUpdate();
			    ins_coach.close();
			} else if (req_type == 2) {
			    PreparedStatement del_coach = con.prepareStatement(
				"DELETE FROM class_coach WHERE group_id = ? AND `date` = ? AND user_id = ?");
			    del_coach.setInt(1, group_id);
			    del_coach.setDate(2, target_date);
			    del_coach.setInt(3, coach_user_id);
			    del_coach.executeUpdate();
			    del_coach.close();
			} else {
			    throw new SQLException("Unknown request type.");
			}

			PreparedStatement del_stmt = con.prepareStatement("DELETE FROM requests WHERE request_id = ?");
			del_stmt.setInt(1, request_id);
			del_stmt.executeUpdate();
			del_stmt.close();

			con.commit();
			message = "Request approved.";
		    } catch (Exception e) {
			con.rollback();
			message = "Unable to approve request: " + e.getMessage();
			message_type = "error";
		    }
		    con.setAutoCommit(true);
		}
	    } else {
		lr.close();
		lookup.close();
		message = "That request no longer exists.";
		message_type = "error";
	    }
	} catch (Exception e) {
	    message = "Unable to process that request.";
	    message_type = "error";
	}
    }

    /* Active groups, for the coach's "submit a request" group picker. */
    java.util.List<java.util.Map<String,Object>> active_groups = new java.util.ArrayList<>();
    if (is_coach) {
	String groups_sql =
	    "SELECT g.group_id, sp.sport_name "
	    + "FROM `groups` g "
	    + "LEFT JOIN sport_groups sg ON sg.group_id = g.group_id "
	    + "LEFT JOIN sports sp ON sp.sport_id = sg.sport_id "
	    + "WHERE g.active_flag = 1 "
	    + "ORDER BY sp.sport_name, g.group_id";
	try {
	    Statement st = con.createStatement();
	    ResultSet rs = st.executeQuery(groups_sql);
	    while (rs.next()) {
		java.util.Map<String,Object> row = new java.util.LinkedHashMap<>();
		row.put("group_id", rs.getInt("group_id"));
		row.put("sport_name", rs.getString("sport_name"));
		active_groups.add(row);
	    }
	    rs.close();
	    st.close();
	} catch (SQLException e) {
	}
    }

    /* This coach's own pending requests. */
    java.util.List<java.util.Map<String,Object>> my_requests = new java.util.ArrayList<>();
    if (is_coach) {
	String sql =
	    "SELECT r.request_id, r.request_type, r.request_text, r.request_date, r.target_date, "
	    + "rg.group_id, sp.sport_name "
	    + "FROM requests r "
	    + "JOIN request_employee re ON re.request_id = r.request_id "
	    + "JOIN request_group rg ON rg.request_id = r.request_id "
	    + "LEFT JOIN sport_groups sg ON sg.group_id = rg.group_id "
	    + "LEFT JOIN sports sp ON sp.sport_id = sg.sport_id "
	    + "WHERE re.user_id = ? "
	    + "ORDER BY r.request_date DESC, r.request_id DESC";
	try {
	    PreparedStatement stmt = con.prepareStatement(sql);
	    stmt.setInt(1, auth_user_id);
	    ResultSet rs = stmt.executeQuery();
	    while (rs.next()) {
		java.util.Map<String,Object> row = new java.util.LinkedHashMap<>();
		row.put("request_id", rs.getInt("request_id"));
		row.put("request_type", rs.getInt("request_type"));
		row.put("request_text", rs.getString("request_text"));
		row.put("request_date", rs.getDate("request_date"));
		row.put("target_date", rs.getDate("target_date"));
		row.put("group_id", rs.getInt("group_id"));
		row.put("sport_name", rs.getString("sport_name"));
		my_requests.add(row);
	    }
	    rs.close();
	    stmt.close();
	} catch (SQLException e) {
	}
    }

    /* Full pending queue, for administrators to approve or reject. */
    java.util.List<java.util.Map<String,Object>> pending_queue = new java.util.ArrayList<>();
    if (is_admin) {
	String sql =
	    "SELECT r.request_id, r.request_type, r.request_text, r.request_date, r.target_date, "
	    + "rg.group_id, sp.sport_name, u.first_name, u.last_name "
	    + "FROM requests r "
	    + "JOIN request_employee re ON re.request_id = r.request_id "
	    + "JOIN request_group rg ON rg.request_id = r.request_id "
	    + "JOIN users u ON u.user_id = re.user_id "
	    + "LEFT JOIN sport_groups sg ON sg.group_id = rg.group_id "
	    + "LEFT JOIN sports sp ON sp.sport_id = sg.sport_id "
	    + "ORDER BY r.request_date, r.request_id";
	try {
	    Statement st = con.createStatement();
	    ResultSet rs = st.executeQuery(sql);
	    while (rs.next()) {
		java.util.Map<String,Object> row = new java.util.LinkedHashMap<>();
		row.put("request_id", rs.getInt("request_id"));
		row.put("request_type", rs.getInt("request_type"));
		row.put("request_text", rs.getString("request_text"));
		row.put("request_date", rs.getDate("request_date"));
		row.put("target_date", rs.getDate("target_date"));
		row.put("group_id", rs.getInt("group_id"));
		row.put("sport_name", rs.getString("sport_name"));
		row.put("employee_name", rs.getString("first_name") + " " + rs.getString("last_name"));
		pending_queue.add(row);
	    }
	    rs.close();
	    st.close();
	} catch (SQLException e) {
	}
    }

    SimpleDateFormat date_fmt = new SimpleDateFormat("EEE, MMM d, yyyy");
    String active_page = "requests";
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8" />
    <title>Requests &mdash; Gym Management System</title>
    <link rel="stylesheet" href="style.css" />
</head>
<body>
    <%@ include file="/WEB-INF/includes/navbar.jspf" %>
    <main class="container">

	<% if (message != null) { %>
	<div class="message <%= "error".equals(message_type) ? "message-error" : "message-success" %>"><%= message %></div>
	<% } %>

	<% if (is_coach) { %>
	<div class="card">
	    <div class="card-header">
		<div>
		    <h1>Submit a Request</h1>
		    <p class="subtitle">Request to cancel a class, take over coaching a session, or step down from one. An administrator will review it.</p>
		</div>
	    </div>
	    <form action="requests.jsp" method="post">
		<input type="hidden" name="form_action" value="submit" />
		<div class="form-row">
		    <label>Request type</label>
		    <select name="request_type" required>
			<option value="0">Cancel a class</option>
			<option value="1">Join as coach for a session</option>
			<option value="2">Leave as coach for a session</option>
		    </select>
		</div>
		<div class="form-row">
		    <label>Group</label>
		    <select name="group_id" required>
			<% for (java.util.Map<String,Object> g : active_groups) { %>
			<option value="<%= g.get("group_id") %>">
			    <%= g.get("sport_name") != null ? g.get("sport_name") : "Group #" + g.get("group_id") %>
			</option>
			<% } %>
		    </select>
		</div>
		<div class="form-row">
		    <label>Target date</label>
		    <input type="date" name="target_date" required />
		</div>
		<div class="form-row">
		    <label>Reason</label>
		    <textarea name="reason" rows="3"></textarea>
		</div>
		<button type="submit" class="btn">Submit Request</button>
	    </form>
	</div>

	<div class="card">
	    <div class="card-header">
		<div>
		    <h2>My Pending Requests</h2>
		    <p class="subtitle">Requests you've submitted that are still waiting for admin review.</p>
		</div>
	    </div>
	    <% if (my_requests.isEmpty()) { %>
	    <p class="empty-state">You have no pending requests.</p>
	    <% } else { %>
	    <div class="table-scroll">
		<table>
		    <thead>
			<tr>
			    <th>Type</th>
			    <th>Group</th>
			    <th>Target Date</th>
			    <th>Reason</th>
			    <th></th>
			</tr>
		    </thead>
		    <tbody>
			<% for (java.util.Map<String,Object> r : my_requests) { %>
			<tr>
			    <td><%= requestTypeLabel((Integer) r.get("request_type")) %></td>
			    <td><%= r.get("sport_name") != null ? r.get("sport_name") : "Group #" + r.get("group_id") %></td>
			    <td><%= date_fmt.format((java.util.Date) r.get("target_date")) %></td>
			    <td><%= r.get("request_text") != null ? r.get("request_text") : "&mdash;" %></td>
			    <td>
				<form action="requests.jsp" method="post" class="inline-form">
				    <input type="hidden" name="form_action" value="withdraw" />
				    <input type="hidden" name="request_id" value="<%= r.get("request_id") %>" />
				    <button type="submit" class="btn btn-danger btn-sm"
					    onclick="return confirm('Withdraw this request?');">Withdraw</button>
				</form>
			    </td>
			</tr>
			<% } %>
		    </tbody>
		</table>
	    </div>
	    <% } %>
	</div>
	<% } %>

	<% if (is_admin) { %>
	<div class="card">
	    <div class="card-header">
		<div>
		    <h2>Pending Requests Queue</h2>
		    <p class="subtitle">Approve to apply the change, or reject to dismiss the request.</p>
		</div>
	    </div>
	    <% if (pending_queue.isEmpty()) { %>
	    <p class="empty-state">No pending requests.</p>
	    <% } else { %>
	    <div class="table-scroll">
		<table>
		    <thead>
			<tr>
			    <th>Coach</th>
			    <th>Type</th>
			    <th>Group</th>
			    <th>Target Date</th>
			    <th>Reason</th>
			    <th></th>
			</tr>
		    </thead>
		    <tbody>
			<% for (java.util.Map<String,Object> r : pending_queue) { %>
			<tr>
			    <td><%= r.get("employee_name") %></td>
			    <td><%= requestTypeLabel((Integer) r.get("request_type")) %></td>
			    <td><%= r.get("sport_name") != null ? r.get("sport_name") : "Group #" + r.get("group_id") %></td>
			    <td><%= date_fmt.format((java.util.Date) r.get("target_date")) %></td>
			    <td><%= r.get("request_text") != null ? r.get("request_text") : "&mdash;" %></td>
			    <td style="white-space: nowrap;">
				<form action="requests.jsp" method="post" class="inline-form">
				    <input type="hidden" name="form_action" value="approve" />
				    <input type="hidden" name="request_id" value="<%= r.get("request_id") %>" />
				    <button type="submit" class="btn btn-sm">Approve</button>
				</form>
				<form action="requests.jsp" method="post" class="inline-form">
				    <input type="hidden" name="form_action" value="reject" />
				    <input type="hidden" name="request_id" value="<%= r.get("request_id") %>" />
				    <button type="submit" class="btn btn-danger btn-sm"
					    onclick="return confirm('Reject this request?');">Reject</button>
				</form>
			    </td>
			</tr>
			<% } %>
		    </tbody>
		</table>
	    </div>
	    <% } %>
	</div>
	<% } %>

    </main>
<%
try { con.close(); } catch (SQLException ignore) {}
%>
</body>
</html>
