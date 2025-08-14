import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _newOptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _recipes = [];
  String? _selectedCourseId;
  String? _selectedCategoryId;
  String _searchQuery = '';

  // For editing
  Map<String, dynamic>? _editingRecipe;

  // Placeholder images for different course types
  final Map<String, String> _courseImages = {
    'Breakfast':
        'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=400&h=200&fit=crop',
    'Dessert':
        'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=400&h=200&fit=crop',
    'Main Dish':
        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&h=200&fit=crop',
    'Snack':
        'https://images.unsplash.com/photo-1599599810694-57a2ca8276a8?w=400&h=200&fit=crop',
  };

  @override
  void initState() {
    super.initState();
    _fetchDropdownOptions();
    _fetchRecipes();
  }

  Future<void> _fetchDropdownOptions() async {
    final client = Supabase.instance.client;
    final courses = await client.from('courses').select();
    final categories = await client.from('categories').select();

    setState(() {
      _courses = List<Map<String, dynamic>>.from(courses);
      _categories = List<Map<String, dynamic>>.from(categories);
    });
  }

  Future<void> _fetchRecipes() async {
    final client = Supabase.instance.client;
    final response = await client
        .from('recipes')
        .select(
          'id, name, description, ingredients, course_id, category_id, courses(name), categories(name)',
        );

    setState(() {
      _recipes = List<Map<String, dynamic>>.from(response);
    });
  }

  void _showAddRecipeDialog([Map<String, dynamic>? existingRecipe]) {
    _editingRecipe = existingRecipe;

    // Populate fields if editing
    if (existingRecipe != null) {
      _titleController.text = existingRecipe['name'] ?? '';
      _descriptionController.text = existingRecipe['description'] ?? '';
      _ingredientsController.text =
          (existingRecipe['ingredients'] as List?)?.join('\n') ?? '';
      _selectedCourseId = existingRecipe['course_id'];
      _selectedCategoryId = existingRecipe['category_id'];
    } else {
      _clearForm();
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(existingRecipe != null ? 'Edit Recipe' : 'Add Recipe'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  TextField(
                    controller: _ingredientsController,
                    decoration: const InputDecoration(labelText: 'Ingredients'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCourseId,
                          hint: const Text('Select Course'),
                          items:
                              _courses.map((course) {
                                return DropdownMenuItem<String>(
                                  value: course['id'] as String,
                                  child: Text(course['name'] as String),
                                );
                              }).toList(),
                          onChanged:
                              (value) =>
                                  setState(() => _selectedCourseId = value),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddOptionDialog('courses'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategoryId,
                          hint: const Text('Select Category'),
                          items:
                              _categories.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat['id'] as String,
                                  child: Text(cat['name'] as String),
                                );
                              }).toList(),
                          onChanged:
                              (value) =>
                                  setState(() => _selectedCategoryId = value),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddOptionDialog('categories'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _clearForm();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _saveRecipe,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text(existingRecipe != null ? 'Update' : 'Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _showAddOptionDialog(String type) async {
    _newOptionController.clear();
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Add to ${type == 'courses' ? 'Courses' : 'Categories'}',
            ),
            content: TextField(
              controller: _newOptionController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = _newOptionController.text.trim();
                  if (name.isEmpty) return;

                  final response =
                      await Supabase.instance.client.from(type).insert({
                        'name': name,
                      }).select();
                  if (response.isNotEmpty) {
                    setState(() {
                      if (type == 'courses') {
                        _courses.add(response.first);
                        _selectedCourseId = response.first['id'];
                      } else {
                        _categories.add(response.first);
                        _selectedCategoryId = response.first['id'];
                      }
                    });
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _saveRecipe() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final ingredients =
        _ingredientsController.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    if (title.isEmpty ||
        _selectedCourseId == null ||
        _selectedCategoryId == null)
      return;

    try {
      if (_editingRecipe != null) {
        // Update existing recipe
        await Supabase.instance.client
            .from('recipes')
            .update({
              'name': title,
              'description': description,
              'ingredients': ingredients,
              'course_id': _selectedCourseId,
              'category_id': _selectedCategoryId,
            })
            .eq('id', _editingRecipe!['id']);
      } else {
        // Add new recipe
        await Supabase.instance.client.from('recipes').insert({
          'name': title,
          'description': description,
          'ingredients': ingredients,
          'course_id': _selectedCourseId,
          'category_id': _selectedCategoryId,
        });
      }

      await _fetchRecipes();
      Navigator.pop(context);
      _clearForm();
    } catch (e) {
      print('Error saving recipe: $e');
    }
  }

  Future<void> _deleteRecipe(Map<String, dynamic> recipe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Recipe'),
            content: Text(
              'Are you sure you want to delete "${recipe['name']}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('recipes')
            .delete()
            .eq('id', recipe['id']);
        await _fetchRecipes();
      } catch (e) {
        print('Error deleting recipe: $e');
      }
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _ingredientsController.clear();
    _selectedCourseId = null;
    _selectedCategoryId = null;
    _editingRecipe = null;
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    floatingActionButton: Container(
      decoration: BoxDecoration(
        color: Color.fromARGB(255, 61, 172, 38),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color.fromARGB(255, 61, 172, 38).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: _showAddRecipeDialog,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    ),
    backgroundColor: const Color(0xFFF5F5F5),
    body: SafeArea(
      child: Column(
        children: [
          // Header with search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Recipe Keeper',
                  style: TextStyle(
                    fontWeight: FontWeight.w600, 
                    fontSize: 20
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search recipes...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ],
            ),
          ),
          // Content area
          Expanded(
            child: _buildCoursesView(),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCoursesView() {
  final courseGroups = <String, List<Map<String, dynamic>>>{};
  
  // Filter recipes based on search query
  final filteredRecipes = _searchQuery.isEmpty
      ? _recipes
      : _recipes.where((recipe) {
          final name = recipe['name']?.toString().toLowerCase() ?? '';
          final description = recipe['description']?.toString().toLowerCase() ?? '';
          final ingredients = (recipe['ingredients'] as List?)?.join(' ').toLowerCase() ?? '';
          return name.contains(_searchQuery) || 
                 description.contains(_searchQuery) || 
                 ingredients.contains(_searchQuery);
        }).toList();

  // Group filtered recipes by course
  for (var recipe in filteredRecipes) {
    final courseName = recipe['courses']?['name'] ?? 'Uncategorized';
    courseGroups.putIfAbsent(courseName, () => []).add(recipe);
  }

  final allCourses = courseGroups.keys.toList();

  if (allCourses.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No recipes found'
                : 'No results for "$_searchQuery"',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.all(20),
    child: GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: allCourses.length,
      itemBuilder: (context, index) {
        final courseName = allCourses[index];
        final recipeCount = courseGroups[courseName]?.length ?? 0;
        
        return GestureDetector(
          onTap: () {
            _navigateToCourseRecipes(courseName, courseGroups[courseName] ?? []);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Background image or color
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: _getCourseColor(courseName),
                    child: _courseImages[courseName] != null && _courseImages[courseName]!.isNotEmpty
                        ? Image.network(
                            _courseImages[courseName]!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: _getCourseColor(courseName),
                            ),
                          )
                        : null,
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Text content
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          courseName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$recipeCount ${recipeCount == 1 ? 'recipe' : 'recipes'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

  Color _getCourseColor(String courseName) {
    switch (courseName.toLowerCase()) {
      case 'breakfast':
        return const Color(0xFFFFB74D);
      case 'dessert':
        return const Color(0xFFE1BEE7);
      case 'main dish':
        return const Color(0xFFFFAB91);
      case 'snack':
        return const Color(0xFFA5D6A7);
      default:
        return const Color(0xFF90CAF9);
    }
  }

  void _navigateToCourseRecipes(
    String courseName,
    List<Map<String, dynamic>> recipes,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => CourseRecipesScreen(
              courseName: courseName,
              recipes: recipes,
              onRecipeUpdated: () {
                _fetchRecipes(); // Refresh recipes when updated
              },
              onEditRecipe: _showAddRecipeDialog,
              onDeleteRecipe: _deleteRecipe,
            ),
      ),
    );
  }
}

class CourseRecipesScreen extends StatefulWidget {
  final String courseName;
  final List<Map<String, dynamic>> recipes;
  final VoidCallback onRecipeUpdated;
  final Function(Map<String, dynamic>) onEditRecipe;
  final Function(Map<String, dynamic>) onDeleteRecipe;

  const CourseRecipesScreen({
    Key? key,
    required this.courseName,
    required this.recipes,
    required this.onRecipeUpdated,
    required this.onEditRecipe,
    required this.onDeleteRecipe,
  }) : super(key: key);

  @override
  State<CourseRecipesScreen> createState() => _CourseRecipesScreenState();
}

class _CourseRecipesScreenState extends State<CourseRecipesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredRecipes {
    if (_searchQuery.isEmpty) return widget.recipes;
    return widget.recipes.where((recipe) {
      final name = recipe['name']?.toString().toLowerCase() ?? '';
      final description = recipe['description']?.toString().toLowerCase() ?? '';
      final ingredients = (recipe['ingredients'] as List?)?.join(' ').toLowerCase() ?? '';
      return name.contains(_searchQuery) || 
             description.contains(_searchQuery) || 
             ingredients.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.courseName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: Colors.black87,
              ),
            ),
            Text(
              '${_filteredRecipes.length} ${_filteredRecipes.length == 1 ? 'recipe' : 'recipes'}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search in ${widget.courseName}...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: _filteredRecipes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _searchQuery.isEmpty ? Icons.receipt_long : Icons.search_off,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No recipes in ${widget.courseName}'
                        : 'No results for "$_searchQuery"',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _filteredRecipes.length,
              itemBuilder: (context, index) {
                final recipe = _filteredRecipes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecipeDetailScreen(
                          recipe: recipe,
                          onEditRecipe: widget.onEditRecipe,
                          onDeleteRecipe: widget.onDeleteRecipe,
                          onRecipeUpdated: widget.onRecipeUpdated,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 61, 172, 38).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.receipt_long,
                                  color: Color.fromARGB(255, 61, 172, 38),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  recipe['name'] ?? 'Untitled Recipe',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    widget.onEditRecipe(recipe);
                                  } else if (value == 'delete') {
                                    widget.onDeleteRecipe(recipe);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 16),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, size: 16, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (recipe['description'] != null && recipe['description'].isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 52),
                              child: Text(
                                recipe['description'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class RecipeDetailScreen extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final Function(Map<String, dynamic>) onEditRecipe;
  final Function(Map<String, dynamic>) onDeleteRecipe;
  final VoidCallback onRecipeUpdated;

  const RecipeDetailScreen({
    required this.recipe,
    required this.onEditRecipe,
    required this.onDeleteRecipe,
    required this.onRecipeUpdated,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ingredients = List<String>.from(recipe['ingredients'] ?? []);
    final course = recipe['courses']?['name'] ?? 'Uncategorized';
    final category = recipe['categories']?['name'] ?? 'Uncategorized';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          recipe['name'] ?? 'Recipe Details',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                onEditRecipe(recipe);
              } else if (value == 'delete') {
                onDeleteRecipe(recipe);
                Navigator.of(context).pop(); // Go back after delete
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('Edit Recipe'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Delete Recipe',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD2691E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (recipe['description'] != null &&
                        recipe['description'].isNotEmpty)
                      Text(
                        recipe['description'],
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                    const SizedBox(height: 20),
                    // Course and Category tags
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Color.fromARGB(
                              255,
                              61,
                              172,
                              38,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            course,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 61, 172, 38),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Ingredients card
            if (ingredients.isNotEmpty)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ingredients',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD2691E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...ingredients.map(
                        (ingredient) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(
                                  top: 8,
                                  right: 12,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color.fromARGB(255, 61, 172, 38),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  ingredient,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
