"""V-Effect 画面遷移図を生成するスクリプト（UIモックアップ版）"""
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Circle, Rectangle
import matplotlib.patheffects as pe
import numpy as np

# --- Japanese font setup ---
try:
    import japanize_matplotlib
except ImportError:
    plt.rcParams['font.family'] = 'MS Gothic'

fig, ax = plt.subplots(1, 1, figsize=(36, 28))
fig.patch.set_facecolor('#0d1117')
ax.set_facecolor('#0d1117')
ax.set_xlim(-2, 36)
ax.set_ylim(-4, 26)
ax.set_aspect('equal')
ax.axis('off')

# ===== Color definitions =====
COL_BG = '#0d1117'
COL_PHONE_BG = '#1a1a2e'
COL_PHONE_BORDER = '#3a3a5c'
COL_AMBER = '#ffb300'
COL_AMBER_DARK = '#ff8f00'
COL_WHITE = '#ffffff'
COL_GRAY = '#888888'
COL_GREEN = '#4caf50'
COL_RED = '#f44336'
COL_BLUE = '#42a5f5'
COL_DEEP_PURPLE = '#7c4dff'

COL_ARROW_REPLACE = '#ff5252'
COL_ARROW_PUSH = '#69f0ae'
COL_ARROW_POP = '#78909c'
COL_TAB = '#4dd0e1'

# Phone frame dimensions
PW = 2.6   # phone width
PH = 4.5   # phone height


def phone_frame(cx, cy, label_below=None):
    """Draw a phone outline and return (left, bottom)."""
    x0 = cx - PW / 2
    y0 = cy - PH / 2
    frame = FancyBboxPatch(
        (x0, y0), PW, PH,
        boxstyle="round,pad=0.15",
        facecolor=COL_PHONE_BG, edgecolor=COL_PHONE_BORDER,
        linewidth=2.2, zorder=5
    )
    ax.add_patch(frame)
    # Status bar line
    ax.plot([x0 + 0.15, x0 + PW - 0.15], [y0 + PH - 0.38, y0 + PH - 0.38],
            color='#444466', lw=0.8, zorder=6)
    if label_below:
        ax.text(cx, y0 - 0.3, label_below, ha='center', va='top',
                fontsize=9.5, color=COL_AMBER, fontweight='bold', zorder=10)
    return x0, y0


def draw_appbar(x0, y0, title, icons_right=None):
    bar_y = y0 + PH - 0.68
    ax.text(x0 + PW / 2, bar_y, title, ha='center', va='center',
            fontsize=7.5, color=COL_WHITE, fontweight='bold', zorder=7)
    if icons_right:
        for i, ic in enumerate(icons_right):
            ax.text(x0 + PW - 0.28 - i * 0.38, bar_y, ic, ha='center', va='center',
                    fontsize=7, color=COL_GRAY, zorder=7)


def draw_textfield(x0, w, y_pos, label):
    tf = FancyBboxPatch(
        (x0 + 0.15, y_pos), w - 0.3, 0.3,
        boxstyle="round,pad=0.04",
        facecolor='#252540', edgecolor='#555577', linewidth=0.8, zorder=6
    )
    ax.add_patch(tf)
    ax.text(x0 + 0.35, y_pos + 0.15, label, ha='left', va='center',
            fontsize=5.2, color=COL_GRAY, zorder=7)


def draw_button(x0, w, y_pos, label, bg_color=COL_AMBER, text_color='#000000'):
    btn = FancyBboxPatch(
        (x0 + 0.2, y_pos), w - 0.4, 0.32,
        boxstyle="round,pad=0.05",
        facecolor=bg_color, edgecolor='none', linewidth=0, zorder=6
    )
    ax.add_patch(btn)
    ax.text(x0 + w / 2, y_pos + 0.16, label, ha='center', va='center',
            fontsize=5.8, color=text_color, fontweight='bold', zorder=7)


def draw_circle_icon(cx, cy, radius, text, bg_color=COL_AMBER, text_color='#000'):
    c = Circle((cx, cy), radius, facecolor=bg_color, edgecolor='none', zorder=6)
    ax.add_patch(c)
    ax.text(cx, cy, text, ha='center', va='center',
            fontsize=int(radius * 35), color=text_color, fontweight='bold', zorder=7)


def draw_bottom_nav(x0, y0, active_idx=0):
    nav_y = y0 + 0.08
    nav_bg = Rectangle((x0 + 0.05, nav_y), PW - 0.1, 0.42,
                        facecolor='#1e1e3a', edgecolor='#444466', linewidth=0.6, zorder=6)
    ax.add_patch(nav_bg)
    icons = ['H', 'C', 'P']
    labels = ['Home', 'Cam', 'Prof']
    for i, (ic, lb) in enumerate(zip(icons, labels)):
        col = COL_AMBER if i == active_idx else COL_GRAY
        ix = x0 + 0.43 + i * (PW - 0.86) / 2
        ax.text(ix, nav_y + 0.27, ic, ha='center', va='center',
                fontsize=9, color=col, fontweight='bold', zorder=7)
        ax.text(ix, nav_y + 0.1, lb, ha='center', va='center',
                fontsize=3.5, color=col, zorder=7)


# ===== Screen drawing functions =====

def draw_login_screen(cx, cy):
    x0, y0 = phone_frame(cx, cy, '/login')
    draw_appbar(x0, y0, 'V-Effect')
    draw_circle_icon(cx, y0 + PH - 1.25, 0.27, 'V', COL_AMBER, '#000')
    draw_textfield(x0, PW, y0 + PH - 1.95, 'mail@example.com')
    draw_textfield(x0, PW, y0 + PH - 2.35, '********')
    draw_button(x0, PW, y0 + PH - 2.82, 'Login')
    # divider
    ax.plot([x0 + 0.2, x0 + PW / 2 - 0.25], [y0 + PH - 3.2, y0 + PH - 3.2],
            color='#444466', lw=0.5, zorder=6)
    ax.plot([x0 + PW / 2 + 0.25, x0 + PW - 0.2], [y0 + PH - 3.2, y0 + PH - 3.2],
            color='#444466', lw=0.5, zorder=6)
    ax.text(cx, y0 + PH - 3.2, 'or', ha='center', va='center',
            fontsize=4.5, color=COL_GRAY, zorder=7)
    draw_button(x0, PW, y0 + PH - 3.55, 'Google Login', '#ffffff', '#333')
    draw_button(x0, PW, y0 + PH - 3.95, 'Apple Login', '#000000', '#fff')
    ax.text(cx, y0 + 0.22, '> Create Account', ha='center', va='center',
            fontsize=5, color=COL_BLUE, zorder=7)


def draw_register_screen(cx, cy):
    x0, y0 = phone_frame(cx, cy, '/register')
    draw_appbar(x0, y0, 'Register')
    draw_circle_icon(cx, y0 + PH - 1.25, 0.27, 'V', COL_AMBER, '#000')
    draw_textfield(x0, PW, y0 + PH - 1.9, 'mail@example.com')
    draw_textfield(x0, PW, y0 + PH - 2.28, 'password')
    draw_textfield(x0, PW, y0 + PH - 2.66, 'confirm password')
    draw_button(x0, PW, y0 + PH - 3.12, 'Create Account')
    ax.plot([x0 + 0.2, x0 + PW / 2 - 0.25], [y0 + PH - 3.5, y0 + PH - 3.5],
            color='#444466', lw=0.5, zorder=6)
    ax.plot([x0 + PW / 2 + 0.25, x0 + PW - 0.2], [y0 + PH - 3.5, y0 + PH - 3.5],
            color='#444466', lw=0.5, zorder=6)
    ax.text(cx, y0 + PH - 3.5, 'or', ha='center', va='center',
            fontsize=4.5, color=COL_GRAY, zorder=7)
    draw_button(x0, PW, y0 + PH - 3.82, 'Google', '#ffffff', '#333')
    draw_button(x0, PW, y0 + PH - 4.15, 'Apple', '#000000', '#fff')


def draw_profile_setup_screen(cx, cy):
    x0, y0 = phone_frame(cx, cy, '/profile-setup (1/2)')
    draw_appbar(x0, y0, 'Profile Setup')
    draw_circle_icon(cx, y0 + PH - 1.15, 0.22, 'U', COL_AMBER, '#000')
    ax.text(cx, y0 + PH - 1.5, 'Step 1 / 2', ha='center', va='center',
            fontsize=5, color=COL_GRAY, zorder=7)
    draw_textfield(x0, PW, y0 + PH - 1.95, 'Username')
    draw_textfield(x0, PW, y0 + PH - 2.33, 'User ID')
    ax.text(x0 + 0.2, y0 + PH - 2.68, 'Date of Birth', ha='left', va='center',
            fontsize=5, color=COL_WHITE, fontweight='bold', zorder=7)
    for i, lbl in enumerate(['YYYY', 'MM', 'DD']):
        bx = x0 + 0.15 + i * 0.78
        dd = FancyBboxPatch((bx, y0 + PH - 3.0), 0.7, 0.22,
                            boxstyle="round,pad=0.03", facecolor='#252540',
                            edgecolor='#555577', linewidth=0.6, zorder=6)
        ax.add_patch(dd)
        ax.text(bx + 0.35, y0 + PH - 2.89, lbl, ha='center', va='center',
                fontsize=4.2, color=COL_GRAY, zorder=7)
    ax.text(x0 + 0.2, y0 + PH - 3.25, 'Gender', ha='left', va='center',
            fontsize=5, color=COL_WHITE, fontweight='bold', zorder=7)
    for i, g in enumerate(['( ) Male', '( ) Female', '( ) Other']):
        ax.text(x0 + 0.35, y0 + PH - 3.5 - i * 0.18, g, ha='left', va='center',
                fontsize=4.5, color=COL_GRAY, zorder=7)
    draw_button(x0, PW, y0 + 0.2, 'Next >')


def draw_task_setup_screen(cx, cy):
    x0, y0 = phone_frame(cx, cy, '/task-setup (2/2)')
    draw_appbar(x0, y0, 'Task Setup')
    draw_circle_icon(cx, y0 + PH - 1.1, 0.22, 'T', COL_AMBER, '#000')
    ax.text(cx, y0 + PH - 1.45, 'Step 2 / 2', ha='center', va='center',
            fontsize=5, color=COL_GRAY, zorder=7)
    photo_c = Circle((cx, y0 + PH - 1.9), 0.28, facecolor='#333355',
                      edgecolor='#555577', linewidth=0.8, zorder=6)
    ax.add_patch(photo_c)
    ax.text(cx, y0 + PH - 1.9, '[+]', ha='center', va='center',
            fontsize=6, color=COL_GRAY, zorder=7)
    ax.text(cx, y0 + PH - 2.28, 'Select Photo', ha='center', va='center',
            fontsize=4.5, color=COL_GRAY, zorder=7)
    ax.text(x0 + 0.2, y0 + PH - 2.58, 'Tasks (1-5)', ha='left', va='center',
            fontsize=5, color=COL_WHITE, fontweight='bold', zorder=7)
    draw_textfield(x0, PW, y0 + PH - 2.9, 'Task 1')
    draw_textfield(x0, PW, y0 + PH - 3.25, 'Task 2')
    ax.text(x0 + 0.2, y0 + PH - 3.6, 'Wake-up:  07:00', ha='left', va='center',
            fontsize=5, color=COL_WHITE, zorder=7)
    ax.text(x0 + 0.2, y0 + PH - 3.85, 'Task time: 08:00', ha='left', va='center',
            fontsize=5, color=COL_WHITE, zorder=7)
    draw_button(x0, PW, y0 + 0.15, 'Start!', COL_AMBER_DARK)


def draw_main_shell(cx, cy):
    x0, y0 = phone_frame(cx, cy, '/home (MainShell)')
    ax.text(cx, cy + 1.2, 'MainShell', ha='center', va='center',
            fontsize=10, color=COL_AMBER, fontweight='bold', zorder=7)
    ax.text(cx, cy + 0.7, 'BottomNavigationBar', ha='center', va='center',
            fontsize=7, color=COL_GRAY, zorder=7)
    ax.text(cx, cy + 0.2, 'IndexedStack:', ha='center', va='center',
            fontsize=6, color='#8888aa', zorder=7)
    # Only Home and Profile are in IndexedStack (camera is pushed)
    for i, (name, note) in enumerate([('HomeScreen', 'Tab 0'),
                                       ('ProfileScreen', 'Tab 2')]):
        ty = cy - 0.3 - i * 0.42
        item_bg = FancyBboxPatch(
            (x0 + 0.2, ty - 0.12), PW - 0.4, 0.32,
            boxstyle="round,pad=0.03", facecolor='#252540',
            edgecolor='#555577', linewidth=0.6, zorder=6
        )
        ax.add_patch(item_bg)
        ax.text(cx - 0.2, ty + 0.04, name, ha='center', va='center',
                fontsize=5.5, color='#aaaacc', zorder=7)
        ax.text(x0 + PW - 0.35, ty + 0.04, note, ha='right', va='center',
                fontsize=4.5, color=COL_AMBER, zorder=7)
    # Note about camera
    ax.text(cx, cy - 1.3, 'CameraScreen', ha='center', va='center',
            fontsize=5.5, color='#666688', zorder=7)
    ax.text(cx, cy - 1.55, '(pushNamed)', ha='center', va='center',
            fontsize=4.5, color=COL_ARROW_PUSH, zorder=7)
    draw_bottom_nav(x0, y0, active_idx=0)


def draw_home_screen(cx, cy):
    x0, y0 = phone_frame(cx, cy, 'HomeScreen [Tab 0]')
    draw_appbar(x0, y0, 'V-Effect', ['N'])
    # Stories row
    story_y = y0 + PH - 1.05
    for i in range(4):
        sx = x0 + 0.38 + i * 0.52
        sc = Circle((sx, story_y), 0.17, facecolor=COL_DEEP_PURPLE,
                     edgecolor=COL_AMBER, linewidth=1.2, zorder=6)
        ax.add_patch(sc)
        ax.text(sx, story_y, 'u', ha='center', va='center',
                fontsize=5, color=COL_WHITE, zorder=7)
        ax.text(sx, story_y - 0.24, f'usr{i+1}', ha='center', va='center',
                fontsize=3.5, color=COL_GRAY, zorder=7)
    # Streak card
    streak_y = y0 + PH - 1.82
    streak_bg = FancyBboxPatch(
        (x0 + 0.12, streak_y), PW - 0.24, 0.52,
        boxstyle="round,pad=0.05", facecolor=COL_AMBER_DARK,
        edgecolor='none', linewidth=0, alpha=0.85, zorder=6
    )
    ax.add_patch(streak_bg)
    ax.text(x0 + 0.3, streak_y + 0.32, '*', ha='center', va='center',
            fontsize=14, color='#ff4444', fontweight='bold', zorder=7)
    ax.text(x0 + 0.58, streak_y + 0.32, '7 days', ha='left', va='center',
            fontsize=7, color=COL_WHITE, fontweight='bold', zorder=7)
    badge = FancyBboxPatch(
        (x0 + PW - 0.78, streak_y + 0.18), 0.52, 0.22,
        boxstyle="round,pad=0.03", facecolor=COL_GREEN,
        edgecolor='none', zorder=6
    )
    ax.add_patch(badge)
    ax.text(x0 + PW - 0.52, streak_y + 0.29, 'Done', ha='center', va='center',
            fontsize=4.5, color=COL_WHITE, fontweight='bold', zorder=7)
    # Tasks
    ax.text(x0 + 0.2, streak_y - 0.22, "Today's Tasks", ha='left', va='center',
            fontsize=5.5, color=COL_WHITE, fontweight='bold', zorder=7)
    tasks = [('[v] Running 3km', COL_GREEN),
             ('[ ] Reading 30min', COL_GRAY),
             ('[ ] English study', COL_GRAY)]
    for i, (t, color) in enumerate(tasks):
        ax.text(x0 + 0.25, streak_y - 0.52 - i * 0.23, t, ha='left', va='center',
                fontsize=4.5, color=color, zorder=7)
    draw_bottom_nav(x0, y0, active_idx=0)


def draw_profile_screen(cx, cy):
    x0, y0 = phone_frame(cx, cy, 'ProfileScreen [Tab 2]')
    draw_appbar(x0, y0, 'Profile', ['N', 'E'])
    av = Circle((cx, y0 + PH - 1.25), 0.32, facecolor='#333355',
                edgecolor=COL_AMBER, linewidth=1.5, zorder=6)
    ax.add_patch(av)
    ax.text(cx, y0 + PH - 1.25, 'U', ha='center', va='center',
            fontsize=11, color=COL_WHITE, fontweight='bold', zorder=7)
    ax.text(cx, y0 + PH - 1.68, 'Username', ha='center', va='center',
            fontsize=7, color=COL_WHITE, fontweight='bold', zorder=7)
    ax.text(cx, y0 + PH - 1.9, '@user_id', ha='center', va='center',
            fontsize=5, color=COL_GRAY, zorder=7)
    ax.text(x0 + 0.2, y0 + PH - 2.15, 'Friends: 5', ha='left', va='center',
            fontsize=5, color=COL_BLUE, zorder=7)
    info = ['DOB: 2000/01/01', 'Email: user@...', 'Streak: 7 days',
            'Wake: 07:00', 'Task: 08:00']
    for i, inf in enumerate(info):
        ax.text(x0 + 0.2, y0 + PH - 2.45 - i * 0.2, inf, ha='left', va='center',
                fontsize=4.5, color=COL_WHITE, zorder=7)
    ax.text(x0 + 0.2, y0 + PH - 3.55, 'Tasks', ha='left', va='center',
            fontsize=5.5, color=COL_WHITE, fontweight='bold', zorder=7)
    for i, t in enumerate(['1. Running 3km', '2. Reading 30min']):
        ax.text(x0 + 0.25, y0 + PH - 3.8 - i * 0.2, t, ha='left', va='center',
                fontsize=4.5, color=COL_GRAY, zorder=7)
    logout_btn = FancyBboxPatch(
        (x0 + 0.3, y0 + 0.55), PW - 0.6, 0.28,
        boxstyle="round,pad=0.04", facecolor='none',
        edgecolor=COL_RED, linewidth=0.8, zorder=6
    )
    ax.add_patch(logout_btn)
    ax.text(cx, y0 + 0.69, 'Logout', ha='center', va='center',
            fontsize=5, color=COL_RED, zorder=7)
    draw_bottom_nav(x0, y0, active_idx=2)


def draw_camera_screen(cx, cy):
    x0, y0 = phone_frame(cx, cy, '/camera')
    draw_appbar(x0, y0, 'Task Proof')
    photo_bg = Rectangle((x0 + 0.15, y0 + 0.95), PW - 0.3, PH - 1.8,
                          facecolor='#222244', edgecolor='#444466', linewidth=0.6, zorder=6)
    ax.add_patch(photo_bg)
    ax.text(cx, cy + 0.5, '[CAM]', ha='center', va='center',
            fontsize=10, color=COL_GRAY, fontweight='bold', zorder=7)
    ax.text(cx, cy - 0.05, 'Take Photo', ha='center', va='center',
            fontsize=6, color=COL_GRAY, zorder=7)
    ax.text(x0 + PW - 0.28, y0 + 1.05, '26/03/08\n14:30', ha='right', va='bottom',
            fontsize=5, color=COL_WHITE, fontweight='bold', zorder=8,
            path_effects=[pe.withStroke(linewidth=1, foreground='black')])
    draw_textfield(x0, PW, y0 + 0.58, "Today's task")
    draw_button(x0, PW, y0 + 0.15, 'Post', COL_AMBER_DARK)


def draw_edit_profile_screen(cx, cy):
    x0, y0 = phone_frame(cx, cy, '/edit-profile')
    draw_appbar(x0, y0, 'Edit Profile')
    warn_bg = FancyBboxPatch(
        (x0 + 0.12, y0 + PH - 1.15), PW - 0.24, 0.38,
        boxstyle="round,pad=0.04", facecolor='#3a1515',
        edgecolor=COL_RED, linewidth=0.6, alpha=0.8, zorder=6
    )
    ax.add_patch(warn_bg)
    ax.text(x0 + 0.25, y0 + PH - 0.96, '(i) 90-day lock', ha='left', va='center',
            fontsize=5, color=COL_RED, zorder=7)
    av = Circle((cx, y0 + PH - 1.62), 0.25, facecolor='#333355',
                edgecolor=COL_AMBER, linewidth=1.2, zorder=6)
    ax.add_patch(av)
    ax.text(cx, y0 + PH - 1.62, '[+]', ha='center', va='center',
            fontsize=6, color=COL_GRAY, zorder=7)
    draw_textfield(x0, PW, y0 + PH - 2.18, 'Username')
    draw_textfield(x0, PW, y0 + PH - 2.55, 'User ID')
    ax.text(x0 + 0.2, y0 + PH - 2.9, 'Date of Birth', ha='left', va='center',
            fontsize=5, color=COL_WHITE, fontweight='bold', zorder=7)
    for i, lbl in enumerate(['YYYY', 'MM', 'DD']):
        bx = x0 + 0.15 + i * 0.78
        dd = FancyBboxPatch((bx, y0 + PH - 3.2), 0.7, 0.22,
                            boxstyle="round,pad=0.03", facecolor='#252540',
                            edgecolor='#555577', linewidth=0.5, zorder=6)
        ax.add_patch(dd)
        ax.text(bx + 0.35, y0 + PH - 3.09, lbl, ha='center', va='center',
                fontsize=4, color=COL_GRAY, zorder=7)
    ax.text(x0 + 0.2, y0 + PH - 3.5, 'Wake-up: 07:00', ha='left', va='center',
            fontsize=5, color=COL_WHITE, zorder=7)
    ax.text(x0 + 0.2, y0 + PH - 3.75, 'Task time: 08:00', ha='left', va='center',
            fontsize=5, color=COL_WHITE, zorder=7)
    draw_button(x0, PW, y0 + 0.15, 'Save', COL_AMBER)


def draw_friends_screen(cx, cy):
    x0, y0 = phone_frame(cx, cy, '/friends')
    draw_appbar(x0, y0, 'Friends')
    ax.text(x0 + 0.2, y0 + PH - 1.0, 'Add Friend', ha='left', va='center',
            fontsize=5.5, color=COL_WHITE, fontweight='bold', zorder=7)
    search_bg = FancyBboxPatch(
        (x0 + 0.15, y0 + PH - 1.42), PW - 0.75, 0.3,
        boxstyle="round,pad=0.04", facecolor='#252540',
        edgecolor='#555577', linewidth=0.6, zorder=6
    )
    ax.add_patch(search_bg)
    ax.text(x0 + 0.3, y0 + PH - 1.27, 'Search by ID...', ha='left', va='center',
            fontsize=4.5, color=COL_GRAY, zorder=7)
    draw_button(x0 + PW - 0.72, 0.58, y0 + PH - 1.42, 'Go', COL_AMBER)
    ax.text(x0 + 0.2, y0 + PH - 1.82, 'Requests', ha='left', va='center',
            fontsize=5.5, color=COL_WHITE, fontweight='bold', zorder=7)
    req_bg = FancyBboxPatch(
        (x0 + 0.15, y0 + PH - 2.22), PW - 0.3, 0.32,
        boxstyle="round,pad=0.03", facecolor='#1e1e35',
        edgecolor='#444466', linewidth=0.5, zorder=6
    )
    ax.add_patch(req_bg)
    ax.text(x0 + 0.3, y0 + PH - 2.06, 'user_abc  @abc', ha='left', va='center',
            fontsize=4.5, color=COL_WHITE, zorder=7)
    ax.text(x0 + PW - 0.25, y0 + PH - 2.06, 'v  x', ha='right', va='center',
            fontsize=6, color=COL_GREEN, zorder=7)
    ax.text(x0 + 0.2, y0 + PH - 2.58, 'Friend List', ha='left', va='center',
            fontsize=5.5, color=COL_WHITE, fontweight='bold', zorder=7)
    friends_data = ['friend_1  @f1', 'friend_2  @f2', 'friend_3  @f3']
    for i, f in enumerate(friends_data):
        fy = y0 + PH - 2.95 - i * 0.3
        item_bg = FancyBboxPatch(
            (x0 + 0.15, fy), PW - 0.3, 0.24,
            boxstyle="round,pad=0.03", facecolor='#1e1e35',
            edgecolor='#444466', linewidth=0.4, zorder=6
        )
        ax.add_patch(item_bg)
        ax.text(x0 + 0.3, fy + 0.12, f, ha='left', va='center',
                fontsize=4.2, color=COL_WHITE, zorder=7)


def draw_notifications_screen(cx, cy):
    x0, y0 = phone_frame(cx, cy, '/notifications')
    draw_appbar(x0, y0, 'Notifications', ['D'])
    notifs = [
        (COL_BLUE, 'Friend request', 'from user_xyz'),
        (COL_GREEN, 'Request accepted', 'friend accepted'),
        (COL_AMBER, 'Wake-up reminder', 'Time to wake up!'),
        (COL_RED, 'Reaction received', 'friend reacted'),
        (COL_AMBER, 'Task completed!', 'All tasks done!'),
    ]
    for i, (color, title, body) in enumerate(notifs):
        ny = y0 + PH - 1.15 - i * 0.6
        card_bg = FancyBboxPatch(
            (x0 + 0.12, ny), PW - 0.24, 0.5,
            boxstyle="round,pad=0.04", facecolor='#1e1e35',
            edgecolor='#333355', linewidth=0.5, zorder=6
        )
        ax.add_patch(card_bg)
        ic = Circle((x0 + 0.38, ny + 0.25), 0.13, facecolor=color,
                     edgecolor='none', alpha=0.35, zorder=6)
        ax.add_patch(ic)
        ax.text(x0 + 0.38, ny + 0.25, '*', ha='center', va='center',
                fontsize=7, color=color, fontweight='bold', zorder=7)
        ax.text(x0 + 0.58, ny + 0.34, title, ha='left', va='center',
                fontsize=4.5, color=COL_WHITE, fontweight='bold', zorder=7)
        ax.text(x0 + 0.58, ny + 0.15, body, ha='left', va='center',
                fontsize=3.8, color=COL_GRAY, zorder=7)


def draw_friend_feed_screen(cx, cy):
    x0, y0 = phone_frame(cx, cy, 'FriendFeedScreen')
    immersive_bg = Rectangle((x0 + 0.05, y0 + 0.05), PW - 0.1, PH - 0.1,
                              facecolor='#000000', edgecolor='none', zorder=5.5)
    ax.add_patch(immersive_bg)
    # Progress bars
    for i in range(4):
        bx = x0 + 0.15 + i * 0.58
        bar_color = COL_WHITE if i < 2 else '#444444'
        ax.plot([bx, bx + 0.48], [y0 + PH - 0.2, y0 + PH - 0.2],
                color=bar_color, lw=2, solid_capstyle='round', zorder=7)
    # Friend icons
    for i in range(3):
        fx = x0 + 0.42 + i * 0.58
        border_col = COL_AMBER if i == 0 else COL_GRAY
        bg_col = COL_DEEP_PURPLE if i == 0 else '#333'
        fc = Circle((fx, y0 + PH - 0.58), 0.16, facecolor=bg_col,
                     edgecolor=border_col, linewidth=1.0, zorder=7)
        ax.add_patch(fc)
        ax.text(fx, y0 + PH - 0.58, 'u', ha='center', va='center',
                fontsize=4.5, color=COL_WHITE, zorder=8)
    # Photo area
    photo_area = Rectangle((x0 + 0.15, y0 + 0.75), PW - 0.3, PH - 1.8,
                            facecolor='#1a1a2e', edgecolor='none', zorder=6)
    ax.add_patch(photo_area)
    ax.text(cx, cy, '[PHOTO]', ha='center', va='center',
            fontsize=9, color='#555577', fontweight='bold', zorder=7)
    ax.text(x0 + PW - 0.28, y0 + 0.9, '26/03/08\n14:30', ha='right', va='bottom',
            fontsize=4.5, color=COL_WHITE, fontweight='bold', zorder=8)
    # Bottom overlay
    grad_bg = Rectangle((x0 + 0.15, y0 + 0.55), PW - 0.3, 0.6,
                          facecolor='#000000', edgecolor='none', alpha=0.7, zorder=7)
    ax.add_patch(grad_bg)
    ax.text(x0 + 0.3, y0 + 0.9, 'Running 3km', ha='left', va='center',
            fontsize=5, color=COL_WHITE, fontweight='bold', zorder=8)
    ax.text(x0 + 0.3, y0 + 0.7, '3h remaining', ha='left', va='center',
            fontsize=4, color='#aaaaaa', zorder=8)
    react_c = Circle((x0 + PW - 0.42, y0 + 0.82), 0.18,
                      facecolor='#ffffff22', edgecolor='none', zorder=8)
    ax.add_patch(react_c)
    ax.text(x0 + PW - 0.42, y0 + 0.82, '*', ha='center', va='center',
            fontsize=12, color=COL_AMBER, fontweight='bold', zorder=9)
    ax.text(x0 + PW - 0.42, y0 + 0.58, '3', ha='center', va='center',
            fontsize=4.5, color=COL_WHITE, zorder=8)
    ax.text(x0 + PW - 0.22, y0 + PH - 0.15, 'x', ha='center', va='center',
            fontsize=7, color=COL_WHITE, fontweight='bold', zorder=8)


# ===== Screen positions (wider spacing) =====
# Row 1 (top): Auth screens
# Row 2 (middle): Setup + MainShell
# Row 3: Main tabs (Home, Camera, Profile, EditProfile)
# Row 4 (bottom): Sub-screens (FriendFeed, Notifications, Friends)

positions = {
    'login':         (3,    22),
    'register':      (3,    15.5),
    'profile_setup': (10,   15.5),
    'task_setup':    (17,   15.5),
    'main_shell':    (17,   22),
    'home':          (5,    8),
    'camera':        (13,   8),
    'profile':       (21,   8),
    'edit_profile':  (29,   8),
    'friend_feed':   (3,    0.5),
    'notifications': (13,   0.5),
    'friends':       (29,   0.5),
}

# ===== Draw all screens =====
draw_login_screen(*positions['login'])
draw_register_screen(*positions['register'])
draw_profile_setup_screen(*positions['profile_setup'])
draw_task_setup_screen(*positions['task_setup'])
draw_main_shell(*positions['main_shell'])
draw_home_screen(*positions['home'])
draw_profile_screen(*positions['profile'])
draw_camera_screen(*positions['camera'])
draw_edit_profile_screen(*positions['edit_profile'])
draw_friends_screen(*positions['friends'])
draw_notifications_screen(*positions['notifications'])
draw_friend_feed_screen(*positions['friend_feed'])


# ===== Arrow drawing =====
def arrow(x1, y1, x2, y2, color, label='', rad=0.0, lw=2.0, ls='-',
          label_offset_x=0, label_offset_y=0, shrink_factor=2.5):
    dx = x2 - x1
    dy = y2 - y1
    length = np.sqrt(dx ** 2 + dy ** 2)
    sx = dx / length * shrink_factor
    sy = dy / length * shrink_factor
    ax.annotate(
        '', xy=(x2 - sx, y2 - sy), xytext=(x1 + sx, y1 + sy),
        arrowprops=dict(
            arrowstyle='-|>', color=color, lw=lw,
            connectionstyle=f'arc3,rad={rad}', linestyle=ls,
            mutation_scale=14,
        ),
        zorder=3
    )
    if label:
        mx = (x1 + x2) / 2 + label_offset_x
        my = (y1 + y2) / 2 + label_offset_y
        if rad != 0:
            perp_x = -dy / length * abs(rad) * 2.2
            perp_y = dx / length * abs(rad) * 2.2
            if rad < 0:
                perp_x, perp_y = -perp_x, -perp_y
            mx += perp_x
            my += perp_y
        ax.text(mx, my, label, ha='center', va='center',
                fontsize=7, color=color, fontweight='bold', zorder=10,
                bbox=dict(boxstyle='round,pad=0.15', facecolor=COL_BG,
                          edgecolor=color, alpha=0.95, linewidth=0.8))


# =============================
# AUTH FLOW
# =============================

# Login -> Register (pushNamed)
arrow(*positions['login'], *positions['register'],
      COL_ARROW_PUSH, 'pushNamed\n"Register"', label_offset_x=2.5)

# Login -> MainShell (pushReplacementNamed on login success)
arrow(*positions['login'], *positions['main_shell'],
      COL_ARROW_REPLACE, 'Login OK\npushReplace', label_offset_y=0.5)

# Register -> ProfileSetup (pushReplacementNamed on signup success)
arrow(*positions['register'], *positions['profile_setup'],
      COL_ARROW_REPLACE, 'Signup OK\npushReplace', label_offset_y=1.0)

# =============================
# SETUP FLOW
# =============================

# ProfileSetup -> TaskSetup (pushReplacementNamed)
arrow(*positions['profile_setup'], *positions['task_setup'],
      COL_ARROW_REPLACE, 'Next\npushReplace', label_offset_y=1.0)

# TaskSetup -> MainShell (pushReplacementNamed)
arrow(*positions['task_setup'], *positions['main_shell'],
      COL_ARROW_REPLACE, 'Complete\npushReplace', label_offset_x=2.0, label_offset_y=2.5)

# =============================
# MAIN SHELL -> TABS
# =============================

# MainShell -> HomeScreen (Tab 0 via IndexedStack)
arrow(*positions['main_shell'], *positions['home'],
      COL_TAB, 'Tab 0\n(IndexedStack)', ls='--', lw=1.8,
      label_offset_x=-2.5, label_offset_y=3.0)

# MainShell -> ProfileScreen (Tab 2 via IndexedStack)
arrow(*positions['main_shell'], *positions['profile'],
      COL_TAB, 'Tab 2\n(IndexedStack)', ls='--', lw=1.8,
      label_offset_x=2.5, label_offset_y=3.0)

# MainShell -> CameraScreen (pushNamed, NOT IndexedStack)
arrow(*positions['main_shell'], *positions['camera'],
      COL_ARROW_PUSH, 'Tab 1 tap\npushNamed', label_offset_x=-2.0, label_offset_y=2.5)

# Camera -> pop back to MainShell
arrow(*positions['camera'], *positions['main_shell'],
      COL_ARROW_POP, 'pop', rad=-0.25, lw=1.5,
      label_offset_x=2.5, label_offset_y=3.0)

# =============================
# HOME SCREEN NAVIGATION
# =============================

# Home -> Notifications (pushNamed)
arrow(*positions['home'], *positions['notifications'],
      COL_ARROW_PUSH, 'Bell icon\npushNamed', label_offset_x=-2.5)

# Home -> FriendFeed (push MaterialPageRoute)
arrow(*positions['home'], *positions['friend_feed'],
      COL_ARROW_PUSH, 'Story tap\npush(Route)', label_offset_x=-2.5, label_offset_y=0.5)

# FriendFeed -> pop back to Home
arrow(*positions['friend_feed'], *positions['home'],
      COL_ARROW_POP, 'pop\n(X / end)', rad=-0.15, lw=1.5,
      label_offset_x=2.5, label_offset_y=0.5)

# Notifications -> pop back (from Home path)
arrow(*positions['notifications'], *positions['home'],
      COL_ARROW_POP, 'pop', rad=0.1, lw=1.5,
      label_offset_x=-3.0, label_offset_y=1.5)

# =============================
# PROFILE SCREEN NAVIGATION
# =============================

# Profile -> Notifications (pushNamed)
arrow(*positions['profile'], *positions['notifications'],
      COL_ARROW_PUSH, 'Bell icon\npushNamed', label_offset_x=2.5)

# Profile -> Friends (pushNamed)
arrow(*positions['profile'], *positions['friends'],
      COL_ARROW_PUSH, 'Friends btn\npushNamed', label_offset_x=2.5)

# Profile -> EditProfile (push MaterialPageRoute)
arrow(*positions['profile'], *positions['edit_profile'],
      COL_ARROW_PUSH, 'Edit icon\npush(Route)', label_offset_y=1.0)

# Profile -> Login (logout, pushReplacementNamed)
arrow(*positions['profile'], *positions['login'],
      COL_ARROW_REPLACE, 'Logout\npushReplace',
      rad=0.08, label_offset_x=-6.0, label_offset_y=6.0)

# EditProfile -> pop back to Profile (returns true)
arrow(*positions['edit_profile'], *positions['profile'],
      COL_ARROW_POP, 'pop(true)', rad=-0.15, lw=1.5,
      label_offset_y=-1.2)

# Notifications -> pop back (from Profile path)
arrow(*positions['notifications'], *positions['profile'],
      COL_ARROW_POP, 'pop', rad=-0.1, lw=1.5,
      label_offset_x=3.0, label_offset_y=1.5)

# Friends -> pop back to Profile
arrow(*positions['friends'], *positions['profile'],
      COL_ARROW_POP, 'pop\n(back)', rad=0.15, lw=1.5,
      label_offset_x=3.0, label_offset_y=1.0)


# ===== Section background labels =====
# Auth
auth_bg = FancyBboxPatch(
    (0.3, 12.8), 6.0, 12.5,
    boxstyle="round,pad=0.4", facecolor='#7b1fa2',
    edgecolor='#ce93d8', linewidth=1.8, alpha=0.07, zorder=1
)
ax.add_patch(auth_bg)
ax.text(3.3, 25.0, 'Auth Flow', fontsize=12, color='#ce93d8',
        ha='center', fontweight='bold', zorder=2)

# Setup
setup_bg = FancyBboxPatch(
    (7.2, 12.8), 12.5, 6.5,
    boxstyle="round,pad=0.4", facecolor='#1565c0',
    edgecolor='#64b5f6', linewidth=1.8, alpha=0.07, zorder=1
)
ax.add_patch(setup_bg)
ax.text(13.5, 19.0, 'Setup Flow', fontsize=12, color='#64b5f6',
        ha='center', fontweight='bold', zorder=2)

# Main App
main_bg = FancyBboxPatch(
    (0.5, -2.5), 33, 13.5,
    boxstyle="round,pad=0.4", facecolor='#00796b',
    edgecolor='#4db6ac', linewidth=1.8, alpha=0.05, zorder=1
)
ax.add_patch(main_bg)
ax.text(17, 11.2, 'Main App', fontsize=12, color='#4db6ac',
        ha='center', fontweight='bold', zorder=2)


# ===== Title =====
ax.text(0.5, 25.5, 'V-Effect Screen Transitions', fontsize=30, fontweight='bold',
        color=COL_AMBER, zorder=10)

# ===== Legend =====
ly = -3.0
arrow_items = [
    (COL_ARROW_REPLACE, '---', 'pushReplacement (no back)'),
    (COL_ARROW_PUSH, '---', 'push / pushNamed (can go back)'),
    (COL_ARROW_POP, '---', 'pop (return)'),
    (COL_TAB, '--', 'Tab switch (IndexedStack)'),
]
for i, (color, _, label) in enumerate(arrow_items):
    lx = 1.0 + i * 8.0
    ls_style = '--' if 'Tab' in label else '-'
    ax.annotate('', xy=(lx + 1.4, ly), xytext=(lx, ly),
                arrowprops=dict(arrowstyle='-|>', color=color, lw=2.5,
                                linestyle=ls_style), zorder=10)
    ax.text(lx + 1.7, ly, label, fontsize=9, color=COL_WHITE, va='center', zorder=10)


plt.tight_layout()
output_path = r'C:\Users\katahara yusuke\V-Effect\docs\screen_transitions.png'
fig.savefig(output_path, dpi=150, bbox_inches='tight',
            facecolor=fig.get_facecolor(), edgecolor='none')
plt.close()
print(f'Saved to {output_path}')
