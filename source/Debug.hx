import lime.app.Application;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.system.debug.log.LogStyle;
import flixel.system.debug.watch.Tracker.TrackerProfile;
import flixel.util.FlxStringUtil;
import haxe.Log;
import haxe.PosInfos;

using StringTools;

/**
 * Hey you, developer!
 * This class contains lots of utility functions for logging and debugging.
 * The goal is to integrate development more heavily with the HaxeFlixel debugger.
 * Use these methods to the fullest to produce mods efficiently!
 * 
 * @see https://haxeflixel.com/documentation/debugger/
 */
class Debug
{
	static final LOG_STYLE_ERROR:LogStyle = new LogStyle('[ERROR] ', 'FF8888', 12, true, false, false, 'flixel/sounds/beep', true);
	static final LOG_STYLE_WARN:LogStyle = new LogStyle('[WARN]  ', 'D9F85C', 12, true, false, false, 'flixel/sounds/beep', true);
	static final LOG_STYLE_INFO:LogStyle = new LogStyle('[INFO]  ', '5CF878', 12, false);
	static final LOG_STYLE_TRACE:LogStyle = new LogStyle('[TRACE] ', '5CF878', 12, false);

	static var logFileWriter:DebugLogWriter = null;

	/**
	 * Log an error message to the game's console.
	 * Plays a beep to the user and forces the console open if this is a debug build.
	 * @param input The message to display.
	 * @param pos This magic type is auto-populated, and includes the line number and class it was called from.
	 */
	public static inline function logError(input:Dynamic, ?pos:haxe.PosInfos):Void
	{
		if (input == null)
			return;

		var output = formatOutput(input, pos);
		writeToFlxGLog(output, LOG_STYLE_ERROR);
		writeToLogFile(output, 'ERROR');
	}

	/**
	 * Log an warning message to the game's console.
	 * Plays a beep to the user and forces the console open if this is a debug build.
	 * @param input The message to display.
	 * @param pos This magic type is auto-populated, and includes the line number and class it was called from.
	 */
	public static inline function logWarn(input:Dynamic, ?pos:haxe.PosInfos):Void
	{
		if (input == null)
			return;

		var output = formatOutput(input, pos);
		writeToFlxGLog(output, LOG_STYLE_WARN);
		writeToLogFile(output, 'WARN');
	}

	/**
	 * Log an info message to the game's console.
	 * @param input The message to display.
	 * @param pos This magic type is auto-populated, and includes the line number and class it was called from.
	 */
	public static inline function logInfo(input:Dynamic, ?pos:haxe.PosInfos):Void
	{
		if (input == null)
			return;

		var output = formatOutput(input, pos);
		writeToFlxGLog(output, LOG_STYLE_INFO);
		writeToLogFile(output, 'INFO');
	}

	/**
	 * Log a trace message to the game's console. Disabled for public builds.
	 * NOTE: We redirect all Haxe `trace()` calls to this function.
	 * @param input The message to display.
	 * @param pos This magic type is auto-populated, and includes the line number and class it was called from.
	 */
	public static function logTrace(input:Dynamic, ?pos:haxe.PosInfos):Void
	{
		#if !PUBLIC_BUILD
		if (input == null)
			return;

		var output = formatOutput(input, pos);
		writeToLogFile(output, 'TRACE');
		#end
	}

	/**
	 * Displays a popup with the provided text.
	 * This interrupts the game, so make sure it's REALLY important.
	 * @param title The title of the popup.
	 * @param description The description of the popup.
	 */
	public static function displayAlert(title:String, description:String):Void
	{
		Application.current.window.alert(description, title);
	}

	/**
	 * Display the value of a particular field of a given object
	 * in the Debug watch window, labelled with the specified name.
	 		* Updates continuously.
	 * @param object The object to watch.
	 * @param field The string name of a field of the above object.
	 * @param name
	 */
	public static inline function watchVariable(object:Dynamic, field:String, name:String):Void
	{
		#if debug
		if (object == null)
		{
			Debug.logError("Tried to watch a variable on a null object!");
			return;
		}

		FlxG.watch.add(object, field, name == null ? field : name);
		#end
		// Else, do nothing outside of debug mode.
	}

	/**
	 * Adds the specified value to the Debug Watch window under the current name.
	 * A lightweight alternative to watchVariable, since it doesn't update until you call it again.
	 * 
	 * @param value 
	 * @param name 
	 */
	public inline static function quickWatch(value:Dynamic, name:String)
	{
		#if debug
		FlxG.watch.addQuick(name == null ? "QuickWatch" : name, value);
		#end
		// Else, do nothing outside of debug mode.
	}

	/**
	 * The Console window already supports most hScript, meaning you can do most things you could already do in Haxe.
	 		* However, you can also add custom commands using this function.
	 */
	public inline static function addConsoleCommand(name:String, callbackFn:Dynamic)
	{
		FlxG.console.registerFunction(name, callbackFn);
	}

	/**
	 * Add an object with a custom alias so that it can be accessed via the console.
	 */
	public inline static function addObject(name:String, object:Dynamic)
	{
		FlxG.console.registerObject(name, object);
	}

	/**
	 * Create a tracker window for an object.
	 * This will display the properties of that object in
	 * a fancy little Debug window you can minimize and drag around.
	 * 
	 * @param obj The object to display.
	 */
	public inline static function trackObject(obj:Dynamic)
	{
		if (obj == null)
		{
			Debug.logError("Tried to track a null object!");
			return;
		}

		FlxG.debugger.track(obj);
	}

	/**
	 * The game runs this function immediately when it starts.
	 		* Use onGameStart() if it can wait until a little later.
	 */
	public static function onInitProgram()
	{
		// Initialize logging tools.
		trace('Initializing Debug tools...');

		// Override Haxe's vanilla trace() calls to use the Flixel console.
		Log.trace = function(data:Dynamic, ?info:PosInfos)
		{
			var paramArray:Array<Dynamic> = [data];

			if (info != null)
			{
				if (info.customParams != null)
				{
					for (i in info.customParams)
					{
						paramArray.push(i);
					}
				}
			}

			logTrace(paramArray, info);
		};

		// Start the log file writer.
		// We have to set it to TRACE for now.
		logFileWriter = new DebugLogWriter("TRACE");

		// logInfo("Debug logging initialized. Hello, developer.");

		#if debug
		logInfo("This is a DEBUG build.");
		#else
		logInfo("This is a RELEASE build.");
		#end
		logInfo('HaxeFlixel version: ${Std.string(FlxG.VERSION)}');
		logInfo('Doki Doki Takeover! version: ${Application.current.meta.get('version')}');
	}

	/**
	 * The game runs this function when it starts, but after Flixel is initialized.
	 */
	public static function onGameStart()
	{
		// Add the mouse position to the debug Watch window.
		FlxG.watch.addMouse();

		defineTrackerProfiles();
		defineConsoleCommands();

		// Now we can remember the log level.
		if (FlxG.save.data.debugLogLevel == null)
			FlxG.save.data.debugLogLevel = "TRACE";

		logFileWriter.setLogLevel(FlxG.save.data.debugLogLevel);
	}

	static function writeToFlxGLog(data:Array<Dynamic>, logStyle:LogStyle)
	{
		if (FlxG != null && FlxG.game != null && FlxG.log != null)
			FlxG.log.advanced(data, logStyle);
	}

	static function writeToLogFile(data:Array<Dynamic>, logLevel:String = "TRACE")
	{
		if (logFileWriter != null && logFileWriter.isActive())
			logFileWriter.write(data, logLevel);
	}

	/**
	 * Defines what properties will be displayed in tracker windows for all these classes.
	 */
	static function defineTrackerProfiles()
	{
		// Example: This will display all the properties that FlxSprite does, along with curCharacter and barColor.
		FlxG.debugger.addTrackerProfile(new TrackerProfile(Character, ["curCharacter", "isPlayer", "barColor"], [FlxSprite]));
		FlxG.debugger.addTrackerProfile(new TrackerProfile(HealthIcon, ["char", "isPlayer", "isOldIcon"], [FlxSprite]));
		FlxG.debugger.addTrackerProfile(new TrackerProfile(Note, ["x", "y", "strumTime", "mustPress", "rawNoteData", "sustainLength"], []));
		FlxG.debugger.addTrackerProfile(new TrackerProfile(Song, [
			"chartVersion",
			"song",
			"speed",
			"player1",
			"player2",
			"gfVersion",
			"noteStyle",
			"stage"
		], []));
	}

	/**
	 * Defines some commands you can run in the console for easy use of important debugging functions.
	 * Feel free to add your own!
	 */
	inline static function defineConsoleCommands()
	{
		// Example: This will display Boyfriend's sprite properties in a debug window.
		addConsoleCommand("trackBoyfriend", function()
		{
			Debug.logInfo("CONSOLE: Begin tracking Boyfriend...");
			trackObject(PlayState.boyfriend);
		});
		addConsoleCommand("trackGirlfriend", function()
		{
			Debug.logInfo("CONSOLE: Begin tracking Girlfriend...");
			trackObject(PlayState.gf);
		});
		addConsoleCommand("trackDad", function()
		{
			Debug.logInfo("CONSOLE: Begin tracking Dad...");
			trackObject(PlayState.dad);
		});

		addConsoleCommand("setLogLevel", function(logLevel:String)
		{
			if (!DebugLogWriter.LOG_LEVELS.contains(logLevel))
			{
				Debug.logWarn('CONSOLE: Invalid log level $logLevel!');
				Debug.logWarn('  Expected: ${DebugLogWriter.LOG_LEVELS.join(', ')}');
			}
			else
			{
				Debug.logInfo('CONSOLE: Setting log level to $logLevel...');
				logFileWriter.setLogLevel(logLevel);
			}
		});

		// Console commands let you do WHATEVER you want.
		addConsoleCommand("playSong", function(songName:String, ?difficulty:Int = 1)
		{
			Debug.logInfo('CONSOLE: Opening song $songName ($difficulty) in Free Play...');
			loadSong(songName, difficulty, false);
		});
		addConsoleCommand("chartSong", function(songName:String, ?difficulty:Int = 1)
		{
			Debug.logInfo('CONSOLE: Opening song $songName ($difficulty) in Chart Editor...');
			loadSong(songName, difficulty, true);
		});

		addConsoleCommand("openState", function(stateName:String)
		{
			Debug.logInfo('CONSOLE: Opening $stateName state...');
			loadState(stateName);
		});
		// Alternative name for above.
		addConsoleCommand("loadState", function(stateName:String)
		{
			Debug.logInfo('CONSOLE: Opening $stateName state...');
			loadState(stateName);
		});
	}

	static function formatOutput(input:Dynamic, pos:haxe.PosInfos):Array<Dynamic>
	{
		// This code is junk but I kept getting Null Function References.
		var inArray:Array<Dynamic> = null;

		if (input == null)
			inArray = ['<NULL>'];
		else if (!Std.isOfType(input, Array))
			inArray = [input];
		else
			inArray = input;

		if (pos == null)
			return inArray;

		// Format the position ourselves.
		var output:Array<Dynamic> = ['(${pos.className}/${pos.methodName}#${pos.lineNumber}): '];

		return output.concat(inArray);
	}

	// Game specific functions.
	inline static function loadSong(songName:String, difficulty:Int = 1, isCharting:Bool = false)
	{
		try
		{
			var poop:String = Highscore.formatSong(songName, difficulty);

			PlayState.isStoryMode = false;
			PlayState.practiceMode = true;
			PlayState.ForceDisableDialogue = true;

			try
			{
				PlayState.SONG = Song.loadFromJson(poop, songName.toLowerCase());
				PlayState.storyDifficulty = difficulty;
			}
			catch (e)
			{
				poop = Highscore.formatSong(songName, 1);
				PlayState.SONG = Song.loadFromJson(poop, songName.toLowerCase());
				PlayState.storyDifficulty = 1;
			}

			if (isCharting)
				LoadingState.loadAndSwitchState(new ChartingState());
			else
				LoadingState.loadAndSwitchState(new PlayState());
		}
		catch (e)
		{
			Debug.logInfo('CONSOLE: An error occured when trying to load the song. Was the name misspelled?');
		}
	}

	inline static function loadState(stateName:String)
	{
		try
		{
			var state:Dynamic;

			switch (stateName)
			{
				default:
					state = new MainMenuState();
				case 'story':
					state = new DokiStoryState();
				case 'freeplay':
					state = new DokiFreeplayState();
				case 'gallery' | 'art' | 'artwork':
					state = new GalleryArtState();
				case 'sticker' | 'stickers':
					state = new GalleryStickerState();
				case 'credit' | 'credits':
					state = new CreditsState();
				case 'option' | 'options':
					state = new OptionsState();
				case 'costume' | 'costumes':
					state = new CostumeSelectState();
				case 'costumeold':
					state = new old.CostumeSelectStateOriginal();
				case 'animation' | 'debug' | 'character':
					state = new AnimationDebugState();
				case 'first' | 'boot' | 'welcome':
					state = new FirstBootState();
				case 'title':
					state = new TitleState();
				case 'thank' | 'thanks' | 'thankyou':
					state = new ThankyouState();
			}

			LoadingState.loadAndSwitchState(state);
		}
		catch (e)
		{
			Debug.logInfo('CONSOLE: An error occured when trying to open the state.');
		}
	}
}

class DebugLogWriter
{
	static final LOG_FOLDER = "logs";
	public static final LOG_LEVELS = ['ERROR', 'WARN', 'INFO', 'TRACE'];

	/**
	 * Set this to the current timestamp that the game started.
	 */
	var startTime:Float = 0;

	var logLevel:Int;

	var active = false;
	#if FEATURE_LOGGING
	var file:sys.io.FileOutput;
	#end

	public function new(logLevelParam:String)
	{
		logLevel = LOG_LEVELS.indexOf(logLevelParam);

		#if FEATURE_LOGGING
		printDebug("Initializing log file...");

		var logFilePath = '$LOG_FOLDER/${Sys.time()}.log';

		// Make sure that the path exists
		if (logFilePath.indexOf("/") != -1)
		{
			var lastIndex:Int = logFilePath.lastIndexOf("/");
			var logFolderPath:String = logFilePath.substr(0, lastIndex);
			printDebug('Creating log folder $logFolderPath');
			sys.FileSystem.createDirectory(logFolderPath);
		}
		// Open the file
		printDebug('Creating log file $logFilePath');
		file = sys.io.File.write(logFilePath, false);
		active = true;
		#else
		printDebug("Won't create log file; no file system access.");
		active = false;
		#end

		// Get the absolute time in seconds. This lets us show relative time in log, which is more readable.
		startTime = getTime(true);
	}

	public function isActive()
	{
		return active;
	}

	/**
	 * Get the time in seconds.
	 * @param abs Whether the timestamp is absolute or relative to the start time.
	 */
	public inline function getTime(abs:Bool = false):Float
	{
		#if sys
		// Use this one on CPP and Neko since it's more accurate.
		return abs ? Sys.time() : (Sys.time() - startTime);
		#else
		// This one is more accurate on non-CPP platforms.
		return abs ? Date.now().getTime() : (Date.now().getTime() - startTime);
		#end
	}

	function shouldLog(input:String):Bool
	{
		var levelIndex = LOG_LEVELS.indexOf(input);

		// Could not find this log level.
		if (levelIndex == -1)
			return false;

		return levelIndex <= logLevel;
	}

	public function setLogLevel(input:String):Void
	{
		var levelIndex = LOG_LEVELS.indexOf(input);

		// Could not find this log level.
		if (levelIndex == -1)
			return;

		logLevel = levelIndex;
		FlxG.save.data.debugLogLevel = logLevel;
	}

	/**
	 * Output text to the log file.
	 */
	public function write(input:Array<Dynamic>, logLevel = 'TRACE'):Void
	{
		var ts = FlxStringUtil.formatTime(getTime(), true);
		var msg = '$ts [${logLevel.rpad(' ', 5)}] ${input.join('')}';

		#if FEATURE_LOGGING
		if (active && file != null)
		{
			if (shouldLog(logLevel))
			{
				file.writeString('$msg\n');
				file.flush();
				file.flush();
			}
		}
		#end

		// Output text to the debug console directly.
		if (shouldLog(logLevel))
			printDebug(msg);
	}

	function printDebug(msg:String)
	{
		#if sys
		Sys.println(msg);
		#else
		// Pass null to exclude the position.
		haxe.Log.trace(msg, null);
		#end
	}
}
