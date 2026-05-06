Analytics on V EFFECT for Monetization

# Why is analytics needed?
We developed an app "V EFFECT" which supplys users a field to show what they make an effort such as work out, study, running etc.
To run this app permanently, we are going to collabolate (or be suponsered) other companies like Redbull. So, some data is needed to show how this app is good for their marketing. 
## Aim
1. Understand how this app is going on, and strategize how to develop.
2. Show how this app is good, and get collaborators.

# Acquired data
When we acquire some data, we need to anonymize their name or user ID.

## App meta data
- Total number of registered users
- Number of monthly active users
- Number of daily active users

## User's data
Everything is linked with user as struct. 
- Number of followed user
- Number of following user
- All of name of tasks they set
- Posted time linked with task name
- HIstory of streaks
- Number of reactions linked with task name

# Analysis
Save history of each daily stats to analyze growth of this app.

## App meta data
- Number of active users per day
    - Percentage of the Firebase free tier
    - **PERPOSE**: to make number of users using this app clear
- Number of active users per month
    - **PORPOSE**: to reveal how this app is going

## User's data
### type of tasks
Examples - Medium size: Fitness, Education, Life. Small size: Gym, Running, Shadow boxing, Push up on Fitness; English, Math, Bookkeeping on Education; Clean up, Cooking, Skin care, Going for a walk. At analytics of similarity, for example, going for a walk is categorized in Life having high cosine similarity to Fitness.
- Categories of tasks users set
    - Morphological analysis using MeCab
    - Categorize tasks into medium size containing small size
        - Caculate cosine similarity between each medium size categories
    - **PURPOSE**: to clear which type of tasks is set by users

- Number of posts linked with each size of categories per day
    - **PORPOSE**: to interpret types of tasks that this app motivate users to do
- Number of reactions per follower linked with small size categories
    - e.g.: 2 followers user received 10 reactions, that means 5 (10 / 2 = 5) reactions per follower
    - **PORPOSE**: to interpret types of tasks which attract other users, or not
- Average of streaks linked with each size of categories
    - **PORPOSE**: to reveal types of tasks which match with this app

### Type of users
Define users by some type of being interested in: Fitness, Education, Nutrition, Craftwork, Body-make, Gardening, Sports, etc. Users can have sub user types in addition to a main type. 
- History of streaks linked with user type
    - **PORPOSE**: to show worth of this app

# Visualization
Make special dashboard only developers can use.
Developers can use the dashboard to highlight the data they want to focus on.
This is intended for a dashboard in a local environment, not for monitoring on Firebase.

# Technical stats
- python
- streamlit
- googletrans library to translate

# Note
App users can use **EVERY** language. On analytics, translate them into English before analize. At dashboard, show us stats in Japanese.
We'd prefer not to use external APIs if possible